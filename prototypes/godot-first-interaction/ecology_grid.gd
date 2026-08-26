class_name PrototypeEcologyGrid
extends RefCounted

# Deliberately small, provisional cellular ecology for the throwaway slice.
# Every update reads one generation and writes the next so traversal order
# cannot change the result.

const WIDTH := 16
const HEIGHT := 11
const CELL_SIZE := 0.72
const ORIGIN := Vector2(-5.4, -3.5)

var moisture := PackedFloat32Array()
var temperature := PackedFloat32Array()
var toxicity := PackedFloat32Array()
var nutrients := PackedFloat32Array()
var dormant_moss := PackedFloat32Array()
var moss := PackedFloat32Array()
var dead_biomass := PackedFloat32Array()
var fungus := PackedFloat32Array()
var fruiting := PackedFloat32Array()
var shade := PackedFloat32Array()
var tick := 0


func _init() -> void:
	var count: int = WIDTH * HEIGHT
	for field in [moisture, temperature, toxicity, nutrients, dormant_moss, moss, dead_biomass, fungus, fruiting, shade]:
		field.resize(count)
	_seed_barren_basin()


func _seed_barren_basin() -> void:
	var hollow := Vector2(-2.7, -1.55)
	var crust := Vector2(4.15, 1.75)
	var vent := Vector2(5.0, 1.65)
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var index: int = _index(x, y)
			var world: Vector2 = world_position(x, y)
			var shelter: float = 1.0 - clampf(world.distance_to(hollow) / 2.6, 0.0, 1.0)
			var vent_influence: float = 1.0 - clampf(world.distance_to(vent) / 2.35, 0.0, 1.0)
			var hollow_seed: float = 1.0 - clampf(world.distance_to(hollow) / 1.25, 0.0, 1.0)
			var crust_seed: float = 1.0 - clampf(world.distance_to(crust) / 1.2, 0.0, 1.0)

			moisture[index] = 0.035 + shelter * 0.15
			temperature[index] = clamp(0.48 + vent_influence * 0.34 - shelter * 0.2, 0.0, 1.0)
			toxicity[index] = clamp(0.06 + vent_influence * 0.72, 0.0, 1.0)
			nutrients[index] = 0.05 + shelter * 0.05
			dormant_moss[index] = max(hollow_seed, crust_seed) * 0.92
			shade[index] = shelter * 0.7


func step() -> void:
	var next_moisture: PackedFloat32Array = moisture.duplicate()
	var next_temperature: PackedFloat32Array = temperature.duplicate()
	var next_toxicity: PackedFloat32Array = toxicity.duplicate()
	var next_nutrients: PackedFloat32Array = nutrients.duplicate()
	var next_dormant: PackedFloat32Array = dormant_moss.duplicate()
	var next_moss: PackedFloat32Array = moss.duplicate()
	var next_dead: PackedFloat32Array = dead_biomass.duplicate()
	var next_fungus: PackedFloat32Array = fungus.duplicate()
	var next_fruiting: PackedFloat32Array = fruiting.duplicate()

	for y in range(HEIGHT):
		for x in range(WIDTH):
			var index: int = _index(x, y)
			var local_moisture: float = moisture[index]
			var local_temperature: float = temperature[index]
			var local_toxicity: float = toxicity[index]
			var local_moss: float = moss[index]
			var local_dead: float = dead_biomass[index]
			var local_fungus: float = fungus[index]
			var local_fruiting: float = fruiting[index]

			var neighbor_moisture: float = _neighbor_average(moisture, x, y)
			var neighbor_moss: float = _neighbor_average(moss, x, y)
			var neighbor_fungus: float = _neighbor_average(fungus, x, y)

			var evaporation: float = (0.0025 + local_temperature * 0.0045) * (1.0 - shade[index] * 0.78) * (1.0 - local_moss * 0.65)
			next_moisture[index] = clamp(lerp(local_moisture, neighbor_moisture, 0.06) - evaporation, 0.0, 1.0)

			# Shade cools gradually; exposed cells drift back toward their seeded heat.
			var heat_target: float = clampf(0.48 + toxicity[index] * 0.28 - shade[index] * 0.3, 0.0, 1.0)
			next_temperature[index] = lerp(local_temperature, heat_target, 0.055)

			var moisture_score: float = smoothstep(0.12, 0.52, local_moisture)
			var temperature_score: float = 1.0 - clampf(absf(local_temperature - 0.4) * 2.5, 0.0, 1.0)
			var moss_suitability: float = moisture_score * temperature_score * (1.0 - local_toxicity)
			var awakening: float = dormant_moss[index] * maxf(0.0, local_moisture - 0.15) * moss_suitability * 0.18
			var spreading: float = neighbor_moss * maxf(0.0, local_moisture - 0.1) * moss_suitability * 0.22
			var moss_growth: float = local_moss * moss_suitability * (0.018 + nutrients[index] * 0.026)
			var dry_decay: float = local_moss * maxf(0.0, 0.13 - local_moisture) * 0.24
			var toxic_decay: float = local_moss * maxf(0.0, local_toxicity - 0.5) * 0.16
			var turnover: float = local_moss * 0.012
			var moss_loss: float = dry_decay + toxic_decay + turnover

			next_moss[index] = clamp(local_moss + awakening + spreading + moss_growth - moss_loss, 0.0, 1.0)
			next_dormant[index] = clamp(dormant_moss[index] - awakening * 0.55, 0.0, 1.0)

			var fungal_moisture: float = smoothstep(0.17, 0.56, local_moisture)
			var fungal_temperature: float = 1.0 - clampf(absf(local_temperature - 0.36) * 2.3, 0.0, 1.0)
			var fungal_suitability: float = fungal_moisture * fungal_temperature * (1.0 - local_toxicity * 0.75)
			var fungal_awakening: float = maxf(0.0, local_dead - 0.015) * fungal_suitability * 0.22
			var fungal_spread: float = neighbor_fungus * fungal_suitability * 0.08
			var fungal_growth: float = local_fungus * local_dead * fungal_suitability * 0.08
			var fungal_decay: float = local_fungus * (0.003 + maxf(0.0, 0.1 - local_moisture) * 0.05)
			var consumption: float = minf(local_dead + moss_loss, local_fungus * 0.032 + fungal_awakening * 0.22)

			next_fungus[index] = clamp(local_fungus + fungal_awakening + fungal_spread + fungal_growth - fungal_decay, 0.0, 1.0)
			next_dead[index] = clamp(local_dead + moss_loss - consumption, 0.0, 1.0)
			next_nutrients[index] = clamp(nutrients[index] + consumption * 0.82 - moss_growth * 0.12, 0.0, 1.0)
			next_toxicity[index] = clamp(local_toxicity - consumption * 0.045, 0.0, 1.0)
			var fruiting_growth: float = local_fungus * (nutrients[index] + 0.08) * local_moisture * fungal_suitability * 0.75
			var fruiting_decay: float = local_fruiting * (0.004 + maxf(0.0, 0.16 - local_moisture) * 0.08)
			next_fruiting[index] = clamp(local_fruiting + fruiting_growth - fruiting_decay, 0.0, 1.0)

	moisture = next_moisture
	temperature = next_temperature
	toxicity = next_toxicity
	nutrients = next_nutrients
	dormant_moss = next_dormant
	moss = next_moss
	dead_biomass = next_dead
	fungus = next_fungus
	fruiting = next_fruiting
	tick += 1


func add_water(world: Vector2, amount := 0.9, radius := 1.35) -> void:
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var distance: float = world_position(x, y).distance_to(world)
			if distance > radius:
				continue
			var strength: float = 1.0 - distance / radius
			var index: int = _index(x, y)
			moisture[index] = clamp(moisture[index] + amount * strength, 0.0, 1.0)


func add_shade(world: Vector2, amount := 0.95, radius := 1.45) -> void:
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var distance: float = world_position(x, y).distance_to(world)
			if distance > radius:
				continue
			var strength: float = 1.0 - distance / radius
			var index: int = _index(x, y)
			shade[index] = clamp(shade[index] + amount * strength, 0.0, 1.0)


func reveal_subsurface_refuge(world: Vector2) -> void:
	add_water(world, 0.62, 1.45)
	add_shade(world, 0.28, 1.55)
	var cell: Vector2i = world_to_cell(world)
	var index: int = _index(cell.x, cell.y)
	dormant_moss[index] = maxf(dormant_moss[index], 0.42)
	nutrients[index] = maxf(nutrients[index], 0.16)


func harvest_world(world: Vector2) -> int:
	var cell: Vector2i = world_to_cell(world)
	var index: int = _index(cell.x, cell.y)
	if fruiting[index] < 0.055:
		return 0
	var amount: float = minf(fruiting[index], 0.24)
	fruiting[index] -= amount
	fungus[index] = maxf(0.0, fungus[index] - amount * 0.16)
	nutrients[index] = maxf(0.0, nutrients[index] - amount * 0.11)
	dead_biomass[index] = clampf(dead_biomass[index] + amount * 0.04, 0.0, 1.0)
	return 1


func graze_cell(cell: Vector2i, amount := 0.13) -> float:
	var x: int = clampi(cell.x, 0, WIDTH - 1)
	var y: int = clampi(cell.y, 0, HEIGHT - 1)
	var index: int = _index(x, y)
	var eaten: float = minf(moss[index], amount)
	moss[index] -= eaten
	return eaten


func deposit_manure(cell: Vector2i, digested_moss: float) -> void:
	var x: int = clampi(cell.x, 0, WIDTH - 1)
	var y: int = clampi(cell.y, 0, HEIGHT - 1)
	var index: int = _index(x, y)
	dead_biomass[index] = clampf(dead_biomass[index] + digested_moss * 0.32, 0.0, 1.0)
	nutrients[index] = clampf(nutrients[index] + digested_moss * 0.58, 0.0, 1.0)


func apply_dust_front(column: int) -> void:
	var x: int = clampi(column, 0, WIDTH - 1)
	for y in range(HEIGHT):
		var index: int = _index(x, y)
		var protection: float = clampf(moss[index] * 0.58 + fungus[index] * 0.22, 0.0, 0.72)
		var moss_damage: float = moss[index] * (1.0 - protection) * 0.12
		moisture[index] = maxf(0.0, moisture[index] - 0.2 * (1.0 - protection))
		temperature[index] = clampf(temperature[index] + 0.16, 0.0, 1.0)
		toxicity[index] = clampf(toxicity[index] + 0.075 * (1.0 - protection), 0.0, 1.0)
		moss[index] = maxf(0.0, moss[index] - moss_damage)
		dead_biomass[index] = clampf(dead_biomass[index] + moss_damage, 0.0, 1.0)
		fruiting[index] *= 0.72 + protection * 0.2


func sample_world(world: Vector2) -> Dictionary:
	var cell: Vector2i = world_to_cell(world)
	var index: int = _index(cell.x, cell.y)
	return {
		"moisture": moisture[index],
		"temperature": temperature[index],
		"toxicity": toxicity[index],
		"nutrients": nutrients[index],
		"dormant_moss": dormant_moss[index],
		"moss": moss[index],
		"dead_biomass": dead_biomass[index],
		"fungus": fungus[index],
		"fruiting": fruiting[index],
		"shade": shade[index]
	}


func summary() -> Dictionary:
	var moss_cells := 0
	var fungus_cells := 0
	var dead_cells := 0
	var fruiting_cells := 0
	var total_moss := 0.0
	var total_fungus := 0.0
	for index in range(WIDTH * HEIGHT):
		total_moss += moss[index]
		total_fungus += fungus[index]
		if moss[index] >= 0.03:
			moss_cells += 1
		if fungus[index] >= 0.012:
			fungus_cells += 1
		if dead_biomass[index] >= 0.035:
			dead_cells += 1
		if fruiting[index] >= 0.055:
			fruiting_cells += 1
	return {
		"moss_cells": moss_cells,
		"fungus_cells": fungus_cells,
		"dead_cells": dead_cells,
		"fruiting_cells": fruiting_cells,
		"total_moss": total_moss,
		"total_fungus": total_fungus,
		"tick": tick
	}


func cell_snapshot(x: int, y: int) -> Dictionary:
	var index: int = _index(x, y)
	return {
		"moisture": moisture[index],
		"temperature": temperature[index],
		"toxicity": toxicity[index],
		"nutrients": nutrients[index],
		"dormant_moss": dormant_moss[index],
		"moss": moss[index],
		"dead_biomass": dead_biomass[index],
		"fungus": fungus[index],
		"fruiting": fruiting[index],
		"shade": shade[index]
	}


func world_position(x: int, y: int) -> Vector2:
	return ORIGIN + Vector2(float(x) * CELL_SIZE, float(y) * CELL_SIZE)


func world_to_cell(world: Vector2) -> Vector2i:
	var local: Vector2 = (world - ORIGIN) / CELL_SIZE
	return Vector2i(clampi(roundi(local.x), 0, WIDTH - 1), clampi(roundi(local.y), 0, HEIGHT - 1))


func _neighbor_average(field: PackedFloat32Array, x: int, y: int) -> float:
	var total: float = field[_index(x, y)]
	var count: int = 1
	for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var nx: int = x + offset.x
		var ny: int = y + offset.y
		if nx < 0 or nx >= WIDTH or ny < 0 or ny >= HEIGHT:
			continue
		total += field[_index(nx, ny)]
		count += 1
	return total / float(count)


func _index(x: int, y: int) -> int:
	return y * WIDTH + x
