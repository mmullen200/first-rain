extends SceneTree

const EcologyGrid = preload("res://ecology_grid.gd")
const AnimalSimulation = preload("res://animal_simulation.gd")
var failed := false


func _init() -> void:
	var ecology = EcologyGrid.new()
	var cell: Vector2i = EcologyGrid.CLOSED_HOLLOW_CELL
	var world: Vector2 = ecology.world_position(cell.x, cell.y)
	ecology.add_resources(cell, {
		"moss": 0.55,
		"fungus": 0.34,
		"microbial_crust": 0.2,
		"nutrients": 0.82,
		"dormant_rhizome": 0.9,
		"dormant_canopy": 0.8,
		"surface_water": 0.62,
		"aquatic_producer": 0.035
	})
	ecology.add_water(world, 0.95, 3.2)
	for simulation_tick in range(140):
		if simulation_tick in [70, 140, 210]:
			ecology.add_water(world, 0.48, 3.2)
		ecology.step()
	var pre_vector: Dictionary = ecology.cell_snapshot(cell.x, cell.y)
	_assert(pre_vector["rhizome"] > 0.0, "moss, crust, and nutrients did not support a rooted mat")
	_assert(pre_vector["ground_bloom"] > 0.0, "rooted plants produced no flowering signal for a flying vector")
	_assert(pre_vector["canopy"] > 0.0, "existing dormant canopy seeds should germinate in suitable habitat")
	ecology.add_resources(cell + Vector2i(-2, 0), {"rhizome": 0.5, "ground_bloom": 0.3, "nutrients": 0.5})
	ecology.add_water(ecology.world_position(cell.x - 2, cell.y), 0.8, 2.0)

	var animals = AnimalSimulation.new(ecology, 17)
	_assert(animals.register_agent("vector", "vector:1", {"cell": cell}), "flying vector fixture did not register")
	for simulation_tick in range(180):
		if simulation_tick % 70 == 0:
			ecology.add_water(world, 0.48, 3.2)
		animals.step()

	var summary: Dictionary = ecology.summary()
	var sample: Dictionary = ecology.cell_snapshot(cell.x, cell.y)
	_assert(summary["rhizome_cells"] > 0, "pioneer soil did not support a reproducing rooted mat")
	_assert(summary["canopy_cells"] > 0, "rooted/decomposer habitat did not support canopy establishment")
	_assert(summary["aquatic_cells"] > 0, "standing water did not support aquatic production")
	_assert(sample["aquatic_consumer"] > 0.0, "aquatic production did not establish a consumer population")
	_assert(summary["total_volatile_sulfur"] > 0.0, "balanced aquatic metabolism produced no volatile sulfur contribution")
	_assert(animals.event_history.any(func(event: Dictionary): return event["taxonomy"] == "organism.pollen_collected"), "flowering plants supplied no finite pollen")
	_assert(sample["canopy_bloom"] > 0.0, "canopy plants produced no distinct blossom signal")
	_assert(animals.event_history.any(func(event: Dictionary): return event["taxonomy"] == "organism.patch_pollinated"), "the flying vector transferred no compatible pollen")
	_assert(sample["dissolved_oxygen"] < 0.9 and sample["dissolved_oxygen"] > 0.0, "aquatic oxygen did not respond within physical bounds")

	if not failed:
		print("PASS: pioneer flowering, habitat-supported canopy germination, compatible pollen and aquatic sulfur processing")
	quit(1 if failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	printerr("FAIL: " + message)
	failed = true
