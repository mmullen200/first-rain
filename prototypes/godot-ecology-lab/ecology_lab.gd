class_name EcologyRulesLab
extends RefCounted

const WIDTH := 22
const HEIGHT := 14
const COUNT := WIDTH * HEIGHT
const MANURE_TRACE_DECAY := 0.004

var moisture := PackedFloat32Array()
var minerals := PackedFloat32Array()
var moss := PackedFloat32Array()
var detritus := PackedFloat32Array()
var fungus := PackedFloat32Array()
var shade := PackedFloat32Array()
var manure_trace := PackedFloat32Array()

var tick := 0
var grazer_cell := Vector2(16.0, 9.0)
var grazer_target := Vector2i(16, 9)
var grazer_hunger := 0.25
var grazer_gut := 0.0
var grazer_digest_ticks := 0
var grazer_state := "roaming"
var last_flows := {}
var initial_nutrients := 0.0
var manure_deposit_count := 0
var total_manure_deposited := 0.0
var last_manure_tick := -1
var last_manure_cell := Vector2i(-1, -1)


func _init() -> void:
	for field in [moisture, minerals, moss, detritus, fungus, shade, manure_trace]:
		field.resize(COUNT)
	reset_dormant()


func reset_dormant() -> void:
	tick = 0
	grazer_cell = Vector2(16.0, 9.0)
	grazer_target = Vector2i(16, 9)
	grazer_hunger = 0.25
	grazer_gut = 0.0
	grazer_digest_ticks = 0
	grazer_state = "dormant"
	manure_deposit_count = 0
	total_manure_deposited = 0.0
	last_manure_tick = -1
	last_manure_cell = Vector2i(-1, -1)
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var i := index(x, y)
			var basin := 1.0 - clampf(Vector2(x, y).distance_to(Vector2(8.0, 7.0)) / 11.0, 0.0, 1.0)
			moisture[i] = 0.07 + basin * 0.08
			minerals[i] = 0.24 + basin * 0.11
			moss[i] = 0.003 if Vector2(x, y).distance_to(Vector2(7.0, 7.0)) < 4.3 else 0.0
			detritus[i] = 0.018 + basin * 0.012
			fungus[i] = 0.001 if Vector2(x, y).distance_to(Vector2(7.0, 7.0)) < 3.2 else 0.0
			shade[i] = clampf(basin * 0.3, 0.0, 1.0)
			manure_trace[i] = 0.0
	initial_nutrients = total_tracked_nutrients()
	_clear_flows()


func reset_established() -> void:
	reset_dormant()
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var i := index(x, y)
			var d := Vector2(x, y).distance_to(Vector2(8.0, 7.0))
			if d < 5.0:
				moisture[i] = 0.48 - d * 0.025
				var transfer := minf(minerals[i] * 0.55, maxf(0.0, 0.34 - d * 0.035))
				minerals[i] -= transfer
				moss[i] += transfer * 0.72
				detritus[i] += transfer * 0.18
				fungus[i] += transfer * 0.10
	grazer_state = "roaming"
	initial_nutrients = total_tracked_nutrients()
	_clear_flows()


func step() -> void:
	_fade_manure_trace()
	var next_moisture := moisture.duplicate()
	var next_minerals := minerals.duplicate()
	var next_moss := moss.duplicate()
	var next_detritus := detritus.duplicate()
	var next_fungus := fungus.duplicate()
	var growth_total := 0.0
	var turnover_total := 0.0
	var decomposed_total := 0.0
	var fungal_turnover_total := 0.0

	for y in range(HEIGHT):
		for x in range(WIDTH):
			var i := index(x, y)
			var wet := moisture[i]
			var local_moss := moss[i]
			var local_fungus := fungus[i]
			var local_detritus := detritus[i]
			var local_minerals := minerals[i]

			var wet_neighbors := neighbor_average(moisture, x, y)
			var moss_neighbors := neighbor_average(moss, x, y)
			var evaporation := (0.000001 + wet * 0.000002) * (1.0 - shade[i] * 0.55) * (1.0 - clampf(local_moss * 1.4, 0.0, 0.6))
			next_moisture[i] = clampf(lerpf(wet, wet_neighbors, 0.004) - evaporation, 0.0, 1.0)

			var water_fit := smoothstep(0.16, 0.42, wet) * (1.0 - smoothstep(0.78, 0.96, wet))
			var propagules := local_moss + moss_neighbors * 0.18 + (0.0006 if local_moss > 0.0 else 0.0)
			var growth := minf(local_minerals, propagules * water_fit * 0.042)
			var drought_stress := maxf(0.0, 0.15 - wet) * 0.16
			var crowding := maxf(0.0, local_moss - 0.52) * 0.018
			var turnover := minf(local_moss, local_moss * (0.0018 + drought_stress) + crowding)

			var fungal_fit := smoothstep(0.13, 0.36, wet) * (1.0 - smoothstep(0.84, 0.98, wet))
			var decomposition := minf(local_detritus, (local_fungus + 0.0004) * fungal_fit * 0.055)
			var fungal_gain := decomposition * 0.22
			var mineral_release := decomposition - fungal_gain
			var fungal_turnover := minf(local_fungus, local_fungus * 0.0032)

			next_minerals[i] += mineral_release - growth
			next_moss[i] = maxf(0.0, local_moss + growth - turnover)
			next_detritus[i] = maxf(0.0, local_detritus + turnover + fungal_turnover - decomposition)
			next_fungus[i] = maxf(0.0, local_fungus + fungal_gain - fungal_turnover)

			growth_total += growth
			turnover_total += turnover
			decomposed_total += decomposition
			fungal_turnover_total += fungal_turnover

	moisture = next_moisture
	minerals = next_minerals
	moss = next_moss
	detritus = next_detritus
	fungus = next_fungus
	var animal_flows := _step_grazer()
	last_flows = {
		"growth": growth_total,
		"turnover": turnover_total + fungal_turnover_total,
		"decomposition": decomposed_total,
		"grazed": animal_flows.grazed,
		"manure": animal_flows.manure,
	}
	tick += 1


func add_water(cell: Vector2i, amount := 0.72, radius := 2.5) -> void:
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var distance := Vector2(x, y).distance_to(Vector2(cell))
			if distance <= radius:
				moisture[index(x, y)] = clampf(moisture[index(x, y)] + amount * (1.0 - distance / radius), 0.0, 1.0)


func apply_drought(cell: Vector2i, radius := 3.4) -> void:
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var distance := Vector2(x, y).distance_to(Vector2(cell))
			if distance > radius:
				continue
			var i := index(x, y)
			var strength := 1.0 - distance / radius
			moisture[i] = maxf(0.0, moisture[i] - 0.62 * strength)
			var killed := minf(moss[i], moss[i] * 0.38 * strength)
			moss[i] -= killed
			detritus[i] += killed


func total_tracked_nutrients() -> float:
	var total := grazer_gut
	for i in range(COUNT):
		total += minerals[i] + moss[i] + detritus[i] + fungus[i]
	return total


func totals() -> Dictionary:
	var result := {"water": 0.0, "minerals": 0.0, "moss": 0.0, "detritus": 0.0, "fungus": 0.0}
	for i in range(COUNT):
		result.water += moisture[i]
		result.minerals += minerals[i]
		result.moss += moss[i]
		result.detritus += detritus[i]
		result.fungus += fungus[i]
	return result


func cell_sample(cell: Vector2i) -> Dictionary:
	var x := clampi(cell.x, 0, WIDTH - 1)
	var y := clampi(cell.y, 0, HEIGHT - 1)
	var i := index(x, y)
	return {"water": moisture[i], "minerals": minerals[i], "moss": moss[i], "detritus": detritus[i], "fungus": fungus[i], "manure_trace": manure_trace[i]}


func _step_grazer() -> Dictionary:
	var grazed := 0.0
	var manure := 0.0
	var moss_total := 0.0
	for value in moss:
		moss_total += value
	if grazer_state == "dormant":
		if moss_total >= 2.2:
			grazer_state = "roaming"
		else:
			return {"grazed": grazed, "manure": manure}

	grazer_hunger = clampf(grazer_hunger + 0.0025, 0.0, 1.0)
	if grazer_digest_ticks > 0:
		grazer_digest_ticks -= 1
		grazer_state = "digesting"
		_roam()
		if grazer_digest_ticks == 0 and grazer_gut > 0.0:
			var cell := Vector2i(roundi(grazer_cell.x), roundi(grazer_cell.y))
			var i := index(clampi(cell.x, 0, WIDTH - 1), clampi(cell.y, 0, HEIGHT - 1))
			manure = grazer_gut
			detritus[i] += grazer_gut * 0.68
			minerals[i] += grazer_gut * 0.32
			manure_trace[i] = 1.0
			manure_deposit_count += 1
			total_manure_deposited += manure
			last_manure_tick = tick + 1
			last_manure_cell = Vector2i(clampi(cell.x, 0, WIDTH - 1), clampi(cell.y, 0, HEIGHT - 1))
			grazer_gut = 0.0
			grazer_state = "roaming"
		return {"grazed": grazed, "manure": manure}

	if grazer_hunger >= 0.58:
		grazer_state = "seeking moss"
		grazer_target = _richest_moss_cell()
		_move_toward_target()
		if grazer_cell.distance_to(Vector2(grazer_target)) < 0.14:
			var i := index(grazer_target.x, grazer_target.y)
			grazed = minf(moss[i], 0.16)
			moss[i] -= grazed
			grazer_gut += grazed
			grazer_hunger = maxf(0.0, grazer_hunger - grazed * 3.4)
			grazer_digest_ticks = 75
	else:
		grazer_state = "roaming"
		_roam()
	return {"grazed": grazed, "manure": manure}


func _roam() -> void:
	if grazer_cell.distance_to(Vector2(grazer_target)) < 0.18:
		var phase := int(tick / 35) % 6
		var offsets := [Vector2i(-3, -1), Vector2i(2, -2), Vector2i(3, 1), Vector2i(1, 3), Vector2i(-2, 2), Vector2i(-3, 0)]
		var current := Vector2i(roundi(grazer_cell.x), roundi(grazer_cell.y))
		grazer_target = Vector2i(clampi(current.x + offsets[phase].x, 0, WIDTH - 1), clampi(current.y + offsets[phase].y, 0, HEIGHT - 1))
	_move_toward_target()


func _move_toward_target() -> void:
	grazer_cell = grazer_cell.move_toward(Vector2(grazer_target), 0.075)


func _richest_moss_cell() -> Vector2i:
	var best := Vector2i(roundi(grazer_cell.x), roundi(grazer_cell.y))
	var best_score := -1.0
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var score := moss[index(x, y)] - Vector2(x, y).distance_to(grazer_cell) * 0.004
			if score > best_score:
				best_score = score
				best = Vector2i(x, y)
	return best


func neighbor_average(field: PackedFloat32Array, x: int, y: int) -> float:
	var total := 0.0
	var count := 0
	for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var nx: int = x + offset.x
		var ny: int = y + offset.y
		if nx >= 0 and nx < WIDTH and ny >= 0 and ny < HEIGHT:
			total += field[index(nx, ny)]
			count += 1
	return total / float(count) if count > 0 else field[index(x, y)]


func _fade_manure_trace() -> void:
	for i in range(COUNT):
		manure_trace[i] = maxf(0.0, manure_trace[i] - MANURE_TRACE_DECAY)


func index(x: int, y: int) -> int:
	return y * WIDTH + x


func _clear_flows() -> void:
	last_flows = {"growth": 0.0, "turnover": 0.0, "decomposition": 0.0, "grazed": 0.0, "manure": 0.0}
