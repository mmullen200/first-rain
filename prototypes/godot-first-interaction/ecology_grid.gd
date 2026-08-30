class_name PrototypeEcologyGrid
extends RefCounted

# Deliberately small, provisional cellular ecology for the throwaway slice.
# Every update reads one generation and writes the next so traversal order
# cannot change the result.

const WIDTH := 24
const HEIGHT := 16
const CELL_SIZE := 2.0
const ORIGIN := Vector2(-7.0, -5.0)

var moisture := PackedFloat32Array()
var temperature := PackedFloat32Array()
var toxicity := PackedFloat32Array()
var nutrients := PackedFloat32Array()
var dormant_moss := PackedFloat32Array()
var moss := PackedFloat32Array()
var dead_biomass := PackedFloat32Array()
var fungus := PackedFloat32Array()
var fruiting := PackedFloat32Array()
var microbial_crust := PackedFloat32Array()
var dormant_rhizome := PackedFloat32Array()
var rhizome := PackedFloat32Array()
var dormant_canopy := PackedFloat32Array()
var canopy := PackedFloat32Array()
var surface_water := PackedFloat32Array()
var aquatic_producer := PackedFloat32Array()
var aquatic_consumer := PackedFloat32Array()
var dissolved_oxygen := PackedFloat32Array()
var sulfur_precursor := PackedFloat32Array()
var volatile_sulfur := PackedFloat32Array()
var ground_bloom := PackedFloat32Array()
var canopy_bloom := PackedFloat32Array()
var pollination := PackedFloat32Array()
var fungal_spores := PackedFloat32Array()
var dam_material := PackedFloat32Array()
var shade := PackedFloat32Array()
var habitat_shade := PackedFloat32Array()
var equipment_shade_world := Vector2.ZERO
var equipment_shade_active := false
var tick := 0


func _init() -> void:
	var count: int = WIDTH * HEIGHT
	for field in [moisture, temperature, toxicity, nutrients, dormant_moss, moss, dead_biomass, fungus, fruiting, microbial_crust, dormant_rhizome, rhizome, dormant_canopy, canopy, surface_water, aquatic_producer, aquatic_consumer, dissolved_oxygen, sulfur_precursor, volatile_sulfur, ground_bloom, canopy_bloom, pollination, fungal_spores, dam_material, shade]:
		field.resize(count)
	_seed_barren_basin()
	habitat_shade = shade.duplicate()


func _seed_barren_basin() -> void:
	var hollow := Vector2(-2.7, -1.55)
	var crust := Vector2(16.0, 3.0)
	var vent := Vector2(17.0, 3.0)
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var index: int = _index(x, y)
			var world: Vector2 = world_position(x, y)
			var shelter: float = 1.0 - clampf(world.distance_to(hollow) / 5.2, 0.0, 1.0)
			var vent_influence: float = 1.0 - clampf(world.distance_to(vent) / 4.7, 0.0, 1.0)
			var hollow_seed: float = 1.0 - clampf(world.distance_to(hollow) / 4.8, 0.0, 1.0)
			var crust_seed: float = 1.0 - clampf(world.distance_to(crust) / 4.6, 0.0, 1.0)

			moisture[index] = 0.035 + shelter * 0.15
			temperature[index] = clamp(0.48 + vent_influence * 0.34 - shelter * 0.2, 0.0, 1.0)
			toxicity[index] = clamp(0.06 + vent_influence * 0.72, 0.0, 1.0)
			nutrients[index] = 0.05 + shelter * 0.05
			dormant_moss[index] = max(hollow_seed, crust_seed) * 0.92
			microbial_crust[index] = crust_seed * 0.16 + hollow_seed * 0.035
			var drainage_affinity: float = clampf((world.x + world.y - 8.0) / 30.0, 0.0, 1.0)
			dormant_rhizome[index] = drainage_affinity * (0.3 + hollow_seed * 0.35)
			dormant_canopy[index] = shelter * 0.14 + drainage_affinity * 0.08
			dissolved_oxygen[index] = 0.72
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
	var next_crust: PackedFloat32Array = microbial_crust.duplicate()
	var next_dormant_rhizome: PackedFloat32Array = dormant_rhizome.duplicate()
	var next_rhizome: PackedFloat32Array = rhizome.duplicate()
	var next_dormant_canopy: PackedFloat32Array = dormant_canopy.duplicate()
	var next_canopy: PackedFloat32Array = canopy.duplicate()
	var next_surface_water: PackedFloat32Array = surface_water.duplicate()
	var next_aquatic_producer: PackedFloat32Array = aquatic_producer.duplicate()
	var next_aquatic_consumer: PackedFloat32Array = aquatic_consumer.duplicate()
	var next_dissolved_oxygen: PackedFloat32Array = dissolved_oxygen.duplicate()
	var next_sulfur_precursor: PackedFloat32Array = sulfur_precursor.duplicate()
	var next_volatile_sulfur: PackedFloat32Array = volatile_sulfur.duplicate()
	var next_ground_bloom: PackedFloat32Array = ground_bloom.duplicate()
	var next_canopy_bloom: PackedFloat32Array = canopy_bloom.duplicate()
	var next_pollination: PackedFloat32Array = pollination.duplicate()
	var next_fungal_spores: PackedFloat32Array = fungal_spores.duplicate()
	var next_dam_material: PackedFloat32Array = dam_material.duplicate()

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
			var local_crust: float = microbial_crust[index]
			var local_rhizome: float = rhizome[index]
			var local_canopy: float = canopy[index]
			var local_surface_water: float = surface_water[index]
			var local_aquatic_producer: float = aquatic_producer[index]
			var local_aquatic_consumer: float = aquatic_consumer[index]
			var local_dam: float = dam_material[index]

			var neighbor_moisture: float = _neighbor_average(moisture, x, y)
			var neighbor_moss: float = _neighbor_average(moss, x, y)
			var neighbor_fungus: float = _neighbor_average(fungus, x, y)
			var neighbor_rhizome: float = _neighbor_average(rhizome, x, y)
			var neighbor_aquatic_producer: float = _neighbor_average(aquatic_producer, x, y)
			var effective_shade: float = clampf(shade[index] + local_canopy * 0.62, 0.0, 1.0)

			var crust_repellency: float = maxf(0.0, local_crust - 0.68) * 0.42
			var evaporation: float = (0.0025 + local_temperature * 0.0045) * (1.0 - effective_shade * 0.78) * (1.0 - local_moss * 0.65)
			next_moisture[index] = clamp(lerp(local_moisture, neighbor_moisture, 0.06) - evaporation, 0.0, 1.0)

			# Shade cools gradually; exposed cells drift back toward their seeded heat.
			var heat_target: float = clampf(0.48 + toxicity[index] * 0.28 - effective_shade * 0.3, 0.0, 1.0)
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
			var fungal_awakening: float = maxf(0.0, local_dead - 0.015) * fungal_suitability * 0.22 + fungal_spores[index] * fungal_suitability * 0.018
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

			# Pioneer crust stabilizes exposed material but dense dry crust can repel
			# incoming water, so it is not a universal retention bonus.
			var crust_moisture: float = 1.0 - clampf(absf(local_moisture - 0.2) * 3.2, 0.0, 1.0)
			var crust_growth: float = local_crust * crust_moisture * (1.0 - local_toxicity) * 0.012
			var crust_decay: float = local_crust * (maxf(0.0, local_moisture - 0.72) * 0.025 + local_canopy * 0.004)
			next_crust[index] = clampf(local_crust + crust_growth - crust_decay, 0.0, 1.0)
			next_nutrients[index] = clampf(next_nutrients[index] + local_crust * 0.0008, 0.0, 1.0)
			next_moisture[index] = maxf(0.0, next_moisture[index] - crust_repellency * 0.003)

			# Rooted mats need pioneer soil and persistent moisture, then stabilize
			# drainage while competing for the same shallow water.
			var rhizome_suitability: float = smoothstep(0.16, 0.5, local_moisture) * smoothstep(0.04, 0.3, nutrients[index]) * (1.0 - local_toxicity)
			var rhizome_awakening: float = dormant_rhizome[index] * maxf(0.0, local_moss + local_crust - 0.08) * rhizome_suitability * 0.045
			var rhizome_spread: float = neighbor_rhizome * rhizome_suitability * 0.016 * (0.45 + pollination[index] * 0.55)
			var rhizome_growth: float = local_rhizome * rhizome_suitability * 0.022
			var rhizome_stress: float = local_rhizome * (maxf(0.0, 0.12 - local_moisture) * 0.08 + local_canopy * 0.006)
			next_rhizome[index] = clampf(local_rhizome + rhizome_awakening + rhizome_spread + rhizome_growth - rhizome_stress, 0.0, 1.0)
			next_dormant_rhizome[index] = maxf(0.0, dormant_rhizome[index] - rhizome_awakening * 0.45)
			next_moisture[index] = maxf(0.0, next_moisture[index] - rhizome_growth * 0.038)
			next_nutrients[index] = maxf(0.0, next_nutrients[index] - rhizome_growth * 0.025)
			next_dead[index] = clampf(next_dead[index] + local_rhizome * 0.0015 + rhizome_stress * 0.5, 0.0, 1.0)

			# Canopy-formers are slow deep-succession producers. They require a
			# functioning rooted/decomposer patch and create shade, litter, and vapor.
			var canopy_suitability: float = smoothstep(0.2, 0.55, local_moisture) * smoothstep(0.08, 0.35, nutrients[index]) * smoothstep(0.05, 0.3, local_fungus + local_rhizome)
			var reproductive_connection: float = 0.35 + pollination[index] * 0.65
			var canopy_awakening: float = dormant_canopy[index] * canopy_suitability * maxf(0.0, local_rhizome - 0.005) * 0.05 * reproductive_connection
			var canopy_growth: float = local_canopy * canopy_suitability * 0.006
			var canopy_stress: float = local_canopy * maxf(0.0, 0.16 - local_moisture) * 0.025
			next_canopy[index] = clampf(local_canopy + canopy_awakening + canopy_growth - canopy_stress, 0.0, 1.0)
			next_dormant_canopy[index] = maxf(0.0, dormant_canopy[index] - canopy_awakening * 0.5)
			next_moisture[index] = maxf(0.0, next_moisture[index] - canopy_growth * 0.055)
			next_dead[index] = clampf(next_dead[index] + local_canopy * 0.0018 + canopy_stress * 0.55, 0.0, 1.0)

			# Flowering is explicitly plant reproduction. Fungal fruiting remains a
			# separate spore pathway and is never treated as a pollen source.
			var ground_flowering: float = local_rhizome * rhizome_suitability * (0.003 + pollination[index] * 0.004)
			var canopy_flowering: float = local_canopy * canopy_suitability * (0.002 + pollination[index] * 0.003)
			next_ground_bloom[index] = clampf(ground_bloom[index] * 0.982 + ground_flowering, 0.0, 1.0)
			next_canopy_bloom[index] = clampf(canopy_bloom[index] * 0.987 + canopy_flowering, 0.0, 1.0)

			# Standing water supports a regulated aquatic food web. Producer blooms
			# generate sulfur precursor, while consumers and oxygen limit runaway gain.
			var pond_gain: float = maxf(0.0, local_moisture - 0.72) * (0.018 - crust_repellency * 0.006) + local_dam * maxf(0.0, local_moisture - 0.28) * 0.006
			var pond_loss: float = (0.0015 + local_temperature * 0.0025) * (1.0 - effective_shade * 0.5) * (1.0 - local_dam * 0.72)
			next_surface_water[index] = clampf(local_surface_water + pond_gain - pond_loss, 0.0, 1.0)
			var oxygen_target: float = clampf(0.62 + local_aquatic_producer * 0.16 - local_aquatic_producer * local_aquatic_producer * 0.34 - local_aquatic_consumer * 0.12, 0.0, 1.0)
			next_dissolved_oxygen[index] = lerpf(dissolved_oxygen[index], oxygen_target, 0.08)
			var aquatic_suitability: float = smoothstep(0.035, 0.2, local_surface_water) * smoothstep(0.03, 0.24, nutrients[index]) * next_dissolved_oxygen[index]
			var aquatic_spread: float = neighbor_aquatic_producer * aquatic_suitability * 0.035
			var aquatic_growth: float = maxf(local_aquatic_producer, 0.006 if local_surface_water > 0.08 else 0.0) * aquatic_suitability * 0.045
			var aquatic_grazing: float = minf(local_aquatic_producer, local_aquatic_consumer * 0.018)
			var aquatic_collapse: float = local_aquatic_producer * maxf(0.0, 0.28 - next_dissolved_oxygen[index]) * 0.08
			next_aquatic_producer[index] = clampf(local_aquatic_producer + aquatic_spread + aquatic_growth - aquatic_grazing - aquatic_collapse, 0.0, 1.0)
			var consumer_growth: float = local_aquatic_consumer * local_aquatic_producer * local_surface_water * 0.035
			var consumer_awakening: float = maxf(0.0, local_aquatic_producer - 0.08) * local_surface_water * 0.008
			var consumer_loss: float = local_aquatic_consumer * (0.003 + maxf(0.0, 0.2 - next_dissolved_oxygen[index]) * 0.05)
			next_aquatic_consumer[index] = clampf(local_aquatic_consumer + consumer_awakening + consumer_growth - consumer_loss, 0.0, 1.0)
			next_nutrients[index] = clampf(next_nutrients[index] - aquatic_growth * 0.04 + aquatic_grazing * 0.025 + aquatic_collapse * 0.5, 0.0, 1.0)
			next_dead[index] = clampf(next_dead[index] + aquatic_collapse * 0.4, 0.0, 1.0)
			var sulfur_created: float = next_aquatic_producer[index] * (0.002 + maxf(0.0, 0.55 - next_dissolved_oxygen[index]) * 0.004)
			var sulfur_processed: float = sulfur_precursor[index] * (0.025 + next_aquatic_consumer[index] * 0.018)
			next_sulfur_precursor[index] = clampf(sulfur_precursor[index] + sulfur_created - sulfur_processed, 0.0, 1.0)
			next_volatile_sulfur[index] = clampf(volatile_sulfur[index] * 0.94 + sulfur_processed * (0.45 + local_surface_water * 0.25), 0.0, 1.0)
			next_pollination[index] = maxf(0.0, pollination[index] * 0.965)
			next_fungal_spores[index] = maxf(0.0, fungal_spores[index] * 0.94)
			next_dam_material[index] = maxf(0.0, local_dam * (0.9992 - local_surface_water * 0.0005))

	# Apply terrain-directed transport after every cell has completed its local
	# update, preserving the double-buffered traversal-order guarantee.
	var drained_moisture := next_moisture.duplicate()
	var drained_nutrients := next_nutrients.duplicate()
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var index: int = _index(x, y)
			var retention: float = 0.22 + next_moss[index] * 0.28 + next_rhizome[index] * 0.18 + next_crust[index] * 0.06 + shade[index] * 0.12 + next_dam_material[index] * 0.48
			var runoff: float = maxf(0.0, next_moisture[index] - retention) * 0.025
			if runoff <= 0.0001 or (x >= WIDTH - 1 and y >= HEIGHT - 1):
				continue
			var downhill := Vector2i(mini(x + 1, WIDTH - 1), y)
			if y < HEIGHT - 1 and (x >= WIDTH - 1 or (x + y) % 2 == 0):
				downhill = Vector2i(x, y + 1)
			var downhill_index: int = _index(downhill.x, downhill.y)
			drained_moisture[index] = maxf(0.0, drained_moisture[index] - runoff)
			drained_moisture[downhill_index] = clampf(drained_moisture[downhill_index] + runoff * 0.9, 0.0, 1.0)
			var mobile_nutrients: float = minf(next_nutrients[index], runoff * 0.035)
			drained_nutrients[index] = maxf(0.0, drained_nutrients[index] - mobile_nutrients)
			drained_nutrients[downhill_index] = clampf(drained_nutrients[downhill_index] + mobile_nutrients * 0.9, 0.0, 1.0)

	moisture = drained_moisture
	temperature = next_temperature
	toxicity = next_toxicity
	nutrients = drained_nutrients
	dormant_moss = next_dormant
	moss = next_moss
	dead_biomass = next_dead
	fungus = next_fungus
	fruiting = next_fruiting
	microbial_crust = next_crust
	dormant_rhizome = next_dormant_rhizome
	rhizome = next_rhizome
	dormant_canopy = next_dormant_canopy
	canopy = next_canopy
	surface_water = next_surface_water
	aquatic_producer = next_aquatic_producer
	aquatic_consumer = next_aquatic_consumer
	dissolved_oxygen = next_dissolved_oxygen
	sulfur_precursor = next_sulfur_precursor
	volatile_sulfur = next_volatile_sulfur
	ground_bloom = next_ground_bloom
	canopy_bloom = next_canopy_bloom
	pollination = next_pollination
	fungal_spores = next_fungal_spores
	dam_material = next_dam_material
	tick += 1


func add_water(world: Vector2, amount := 0.9, radius := 4.0) -> void:
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var distance: float = world_position(x, y).distance_to(world)
			if distance > radius:
				continue
			var strength: float = 1.0 - distance / radius
			var index: int = _index(x, y)
			moisture[index] = clamp(moisture[index] + amount * strength, 0.0, 1.0)
			var basin_depth: float = clampf(float(x + y) / float(WIDTH + HEIGHT - 2), 0.0, 1.0)
			surface_water[index] = clampf(surface_water[index] + amount * strength * basin_depth * 0.16, 0.0, 1.0)


func add_shade(world: Vector2, amount := 0.95, radius := 4.0) -> void:
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var distance: float = world_position(x, y).distance_to(world)
			if distance > radius:
				continue
			var strength: float = 1.0 - distance / radius
			var index: int = _index(x, y)
			habitat_shade[index] = clamp(habitat_shade[index] + amount * strength, 0.0, 1.0)
	_rebuild_shade()


func place_equipment_shade(world: Vector2) -> void:
	equipment_shade_world = world
	equipment_shade_active = true
	_rebuild_shade()


func remove_equipment_shade() -> void:
	equipment_shade_active = false
	_rebuild_shade()


func _rebuild_shade() -> void:
	shade = habitat_shade.duplicate()
	if not equipment_shade_active:
		return
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var distance: float = world_position(x, y).distance_to(equipment_shade_world)
			if distance > 4.0:
				continue
			var strength: float = 1.0 - distance / 4.0
			var index: int = _index(x, y)
			shade[index] = clampf(shade[index] + 0.95 * strength, 0.0, 1.0)


func reveal_subsurface_refuge(world: Vector2) -> void:
	add_water(world, 0.62, 4.2)
	add_shade(world, 0.28, 4.4)
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


func resource_amount(cell: Vector2i, resource: String) -> float:
	var index: int = _index(clampi(cell.x, 0, WIDTH - 1), clampi(cell.y, 0, HEIGHT - 1))
	match resource:
		"moisture":
			return moisture[index]
		"moss":
			return moss[index]
		"dead_biomass":
			return dead_biomass[index]
		"nutrients":
			return nutrients[index]
		"fungus":
			return fungus[index]
		"fruiting":
			return fruiting[index]
		"microbial_crust":
			return microbial_crust[index]
		"dormant_rhizome":
			return dormant_rhizome[index]
		"rhizome":
			return rhizome[index]
		"dormant_canopy":
			return dormant_canopy[index]
		"canopy":
			return canopy[index]
		"surface_water":
			return surface_water[index]
		"aquatic_producer":
			return aquatic_producer[index]
		"aquatic_consumer":
			return aquatic_consumer[index]
		"ground_bloom":
			return ground_bloom[index]
		"canopy_bloom":
			return canopy_bloom[index]
		"pollination":
			return pollination[index]
		"fungal_spores":
			return fungal_spores[index]
		"dam_material":
			return dam_material[index]
	return 0.0


func consume_resource(cell: Vector2i, resource: String, requested: float) -> float:
	var index: int = _index(clampi(cell.x, 0, WIDTH - 1), clampi(cell.y, 0, HEIGHT - 1))
	var consumed := minf(resource_amount(cell, resource), maxf(0.0, requested))
	match resource:
		"moss":
			moss[index] -= consumed
		"dead_biomass":
			dead_biomass[index] -= consumed
		"nutrients":
			nutrients[index] -= consumed
		"fungus":
			fungus[index] -= consumed
		"fruiting":
			fruiting[index] -= consumed
		"microbial_crust":
			microbial_crust[index] -= consumed
		"rhizome":
			rhizome[index] -= consumed
		"canopy":
			canopy[index] -= consumed
		"aquatic_producer":
			aquatic_producer[index] -= consumed
		"aquatic_consumer":
			aquatic_consumer[index] -= consumed
		"ground_bloom":
			ground_bloom[index] -= consumed
		"canopy_bloom":
			canopy_bloom[index] -= consumed
		"pollination":
			pollination[index] -= consumed
		"fungal_spores":
			fungal_spores[index] -= consumed
		"dam_material":
			dam_material[index] -= consumed
		_:
			return 0.0
	return consumed


func add_resources(cell: Vector2i, resources: Dictionary) -> Dictionary:
	var index: int = _index(clampi(cell.x, 0, WIDTH - 1), clampi(cell.y, 0, HEIGHT - 1))
	var accepted := {}
	for resource in resources:
		var requested: float = maxf(0.0, float(resources[resource]))
		var before := resource_amount(cell, resource)
		match resource:
			"moss":
				moss[index] = clampf(moss[index] + requested, 0.0, 1.0)
			"dead_biomass":
				dead_biomass[index] = clampf(dead_biomass[index] + requested, 0.0, 1.0)
			"nutrients":
				nutrients[index] = clampf(nutrients[index] + requested, 0.0, 1.0)
			"fungus":
				fungus[index] = clampf(fungus[index] + requested, 0.0, 1.0)
			"fruiting":
				fruiting[index] = clampf(fruiting[index] + requested, 0.0, 1.0)
			"microbial_crust":
				microbial_crust[index] = clampf(microbial_crust[index] + requested, 0.0, 1.0)
			"dormant_rhizome":
				dormant_rhizome[index] = clampf(dormant_rhizome[index] + requested, 0.0, 1.0)
			"rhizome":
				rhizome[index] = clampf(rhizome[index] + requested, 0.0, 1.0)
			"dormant_canopy":
				dormant_canopy[index] = clampf(dormant_canopy[index] + requested, 0.0, 1.0)
			"canopy":
				canopy[index] = clampf(canopy[index] + requested, 0.0, 1.0)
			"surface_water":
				surface_water[index] = clampf(surface_water[index] + requested, 0.0, 1.0)
			"aquatic_producer":
				aquatic_producer[index] = clampf(aquatic_producer[index] + requested, 0.0, 1.0)
			"aquatic_consumer":
				aquatic_consumer[index] = clampf(aquatic_consumer[index] + requested, 0.0, 1.0)
			"ground_bloom":
				ground_bloom[index] = clampf(ground_bloom[index] + requested, 0.0, 1.0)
			"canopy_bloom":
				canopy_bloom[index] = clampf(canopy_bloom[index] + requested, 0.0, 1.0)
			"pollination":
				pollination[index] = clampf(pollination[index] + requested, 0.0, 1.0)
			"fungal_spores":
				fungal_spores[index] = clampf(fungal_spores[index] + requested, 0.0, 1.0)
			"dam_material":
				dam_material[index] = clampf(dam_material[index] + requested, 0.0, 1.0)
			_:
				continue
		accepted[resource] = resource_amount(cell, resource) - before
	return accepted


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
		"microbial_crust": microbial_crust[index],
		"dormant_rhizome": dormant_rhizome[index],
		"rhizome": rhizome[index],
		"dormant_canopy": dormant_canopy[index],
		"canopy": canopy[index],
		"surface_water": surface_water[index],
		"aquatic_producer": aquatic_producer[index],
		"aquatic_consumer": aquatic_consumer[index],
		"dissolved_oxygen": dissolved_oxygen[index],
		"sulfur_precursor": sulfur_precursor[index],
		"volatile_sulfur": volatile_sulfur[index],
		"ground_bloom": ground_bloom[index],
		"canopy_bloom": canopy_bloom[index],
		"pollination": pollination[index],
		"fungal_spores": fungal_spores[index],
		"dam_material": dam_material[index],
		"shade": shade[index]
	}


func summary() -> Dictionary:
	var moss_cells := 0
	var fungus_cells := 0
	var dead_cells := 0
	var fruiting_cells := 0
	var total_moss := 0.0
	var total_fungus := 0.0
	var rhizome_cells := 0
	var canopy_cells := 0
	var aquatic_cells := 0
	var total_volatile_sulfur := 0.0
	var total_canopy := 0.0
	var total_surface_water := 0.0
	var total_pollination := 0.0
	var total_ground_bloom := 0.0
	var total_canopy_bloom := 0.0
	var total_fungal_spores := 0.0
	var total_dam_material := 0.0
	for index in range(WIDTH * HEIGHT):
		total_moss += moss[index]
		total_fungus += fungus[index]
		total_volatile_sulfur += volatile_sulfur[index]
		total_canopy += canopy[index]
		total_surface_water += surface_water[index]
		total_pollination += pollination[index]
		total_ground_bloom += ground_bloom[index]
		total_canopy_bloom += canopy_bloom[index]
		total_fungal_spores += fungal_spores[index]
		total_dam_material += dam_material[index]
		if moss[index] >= 0.03:
			moss_cells += 1
		if fungus[index] >= 0.012:
			fungus_cells += 1
		if dead_biomass[index] >= 0.035:
			dead_cells += 1
		if fruiting[index] >= 0.055:
			fruiting_cells += 1
		if rhizome[index] >= 0.008:
			rhizome_cells += 1
		if canopy[index] >= 0.002:
			canopy_cells += 1
		if aquatic_producer[index] >= 0.004:
			aquatic_cells += 1
	return {
		"moss_cells": moss_cells,
		"fungus_cells": fungus_cells,
		"dead_cells": dead_cells,
		"fruiting_cells": fruiting_cells,
		"total_moss": total_moss,
		"total_fungus": total_fungus,
		"rhizome_cells": rhizome_cells,
		"canopy_cells": canopy_cells,
		"aquatic_cells": aquatic_cells,
		"total_volatile_sulfur": total_volatile_sulfur,
		"total_canopy": total_canopy,
		"total_surface_water": total_surface_water,
		"total_pollination": total_pollination,
		"total_ground_bloom": total_ground_bloom,
		"total_canopy_bloom": total_canopy_bloom,
		"total_fungal_spores": total_fungal_spores,
		"total_dam_material": total_dam_material,
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
		"microbial_crust": microbial_crust[index],
		"dormant_rhizome": dormant_rhizome[index],
		"rhizome": rhizome[index],
		"dormant_canopy": dormant_canopy[index],
		"canopy": canopy[index],
		"surface_water": surface_water[index],
		"aquatic_producer": aquatic_producer[index],
		"aquatic_consumer": aquatic_consumer[index],
		"dissolved_oxygen": dissolved_oxygen[index],
		"sulfur_precursor": sulfur_precursor[index],
		"volatile_sulfur": volatile_sulfur[index],
		"ground_bloom": ground_bloom[index],
		"canopy_bloom": canopy_bloom[index],
		"pollination": pollination[index],
		"fungal_spores": fungal_spores[index],
		"dam_material": dam_material[index],
		"shade": shade[index]
	}


func full_snapshot() -> Dictionary:
	return {
		"version": 1,
		"tick": tick,
		"width": WIDTH,
		"height": HEIGHT,
		"moisture": moisture.duplicate(),
		"temperature": temperature.duplicate(),
		"toxicity": toxicity.duplicate(),
		"nutrients": nutrients.duplicate(),
		"dormant_moss": dormant_moss.duplicate(),
		"moss": moss.duplicate(),
		"dead_biomass": dead_biomass.duplicate(),
		"fungus": fungus.duplicate(),
		"fruiting": fruiting.duplicate(),
		"microbial_crust": microbial_crust.duplicate(),
		"dormant_rhizome": dormant_rhizome.duplicate(),
		"rhizome": rhizome.duplicate(),
		"dormant_canopy": dormant_canopy.duplicate(),
		"canopy": canopy.duplicate(),
		"surface_water": surface_water.duplicate(),
		"aquatic_producer": aquatic_producer.duplicate(),
		"aquatic_consumer": aquatic_consumer.duplicate(),
		"dissolved_oxygen": dissolved_oxygen.duplicate(),
		"sulfur_precursor": sulfur_precursor.duplicate(),
		"volatile_sulfur": volatile_sulfur.duplicate(),
		"ground_bloom": ground_bloom.duplicate(),
		"canopy_bloom": canopy_bloom.duplicate(),
		"pollination": pollination.duplicate(),
		"fungal_spores": fungal_spores.duplicate(),
		"dam_material": dam_material.duplicate(),
		"shade": shade.duplicate(),
		"habitat_shade": habitat_shade.duplicate(),
		"equipment_shade_world": equipment_shade_world,
		"equipment_shade_active": equipment_shade_active
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	if int(snapshot.get("version", 0)) != 1:
		return false
	if int(snapshot.get("width", 0)) != WIDTH or int(snapshot.get("height", 0)) != HEIGHT:
		return false
	for field_name in ["moisture", "temperature", "toxicity", "nutrients", "dormant_moss", "moss", "dead_biomass", "fungus", "fruiting", "microbial_crust", "dormant_rhizome", "rhizome", "dormant_canopy", "canopy", "surface_water", "aquatic_producer", "aquatic_consumer", "dissolved_oxygen", "sulfur_precursor", "volatile_sulfur", "ground_bloom", "canopy_bloom", "pollination", "fungal_spores", "dam_material", "shade"]:
		if not snapshot.has(field_name) or snapshot[field_name].size() != WIDTH * HEIGHT:
			return false
	moisture = snapshot["moisture"].duplicate()
	temperature = snapshot["temperature"].duplicate()
	toxicity = snapshot["toxicity"].duplicate()
	nutrients = snapshot["nutrients"].duplicate()
	dormant_moss = snapshot["dormant_moss"].duplicate()
	moss = snapshot["moss"].duplicate()
	dead_biomass = snapshot["dead_biomass"].duplicate()
	fungus = snapshot["fungus"].duplicate()
	fruiting = snapshot["fruiting"].duplicate()
	microbial_crust = snapshot["microbial_crust"].duplicate()
	dormant_rhizome = snapshot["dormant_rhizome"].duplicate()
	rhizome = snapshot["rhizome"].duplicate()
	dormant_canopy = snapshot["dormant_canopy"].duplicate()
	canopy = snapshot["canopy"].duplicate()
	surface_water = snapshot["surface_water"].duplicate()
	aquatic_producer = snapshot["aquatic_producer"].duplicate()
	aquatic_consumer = snapshot["aquatic_consumer"].duplicate()
	dissolved_oxygen = snapshot["dissolved_oxygen"].duplicate()
	sulfur_precursor = snapshot["sulfur_precursor"].duplicate()
	volatile_sulfur = snapshot["volatile_sulfur"].duplicate()
	ground_bloom = snapshot["ground_bloom"].duplicate()
	canopy_bloom = snapshot["canopy_bloom"].duplicate()
	pollination = snapshot["pollination"].duplicate()
	fungal_spores = snapshot["fungal_spores"].duplicate()
	dam_material = snapshot["dam_material"].duplicate()
	shade = snapshot["shade"].duplicate()
	habitat_shade = snapshot.get("habitat_shade", shade).duplicate()
	equipment_shade_world = snapshot.get("equipment_shade_world", Vector2.ZERO)
	equipment_shade_active = bool(snapshot.get("equipment_shade_active", false))
	tick = int(snapshot["tick"])
	return true


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
