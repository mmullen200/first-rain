extends SceneTree

const EcologyGrid = preload("res://ecology_grid.gd")
const AnimalSimulation = preload("res://animal_simulation.gd")


func _init() -> void:
	var ecology = EcologyGrid.new()
	var simulation = AnimalSimulation.new(ecology, 73)
	var colony_cell := Vector2i(4, 4)
	var vector_cell := Vector2i(8, 7)
	var spore_cell := Vector2i(7, 6)
	var engineer_cell: Vector2i = EcologyGrid.CHANNEL_CELL
	ecology.add_resources(colony_cell, {"dead_biomass": 0.42})
	ecology.add_resources(vector_cell, {"rhizome": 0.42, "ground_bloom": 0.28})
	ecology.add_resources(spore_cell, {"fruiting": 0.3, "dead_biomass": 0.22})
	ecology.add_water(ecology.world_position(spore_cell.x, spore_cell.y), 0.65, 0.8)
	ecology.add_resources(engineer_cell, {"dead_biomass": 0.35, "surface_water": 0.28})

	_assert(simulation.register_agent("colony", "colony:1", {"cell": colony_cell, "hunger": 0.8}), "colony should register")
	_assert(simulation.register_agent("vector", "vector:1", {"cell": vector_cell}), "vector should register")
	_assert(simulation.register_agent("vector", "vector:spores", {"cell": spore_cell}), "spore-dispersing animal should register through the vector role")
	_assert(simulation.register_agent("wetland_engineer", "engineer:1", {"cell": engineer_cell}), "engineer should register")
	var nutrients_before := ecology.resource_amount(colony_cell, "nutrients")
	for _step in range(4):
		simulation.step()

	_assert(ecology.resource_amount(colony_cell, "nutrients") > nutrients_before, "colony should recycle detritus into available nutrients")
	_assert(ecology.resource_amount(vector_cell, "pollination") > 0.0, "vector should connect reproductive patches through pollination")
	_assert(ecology.resource_amount(spore_cell, "fungal_spores") > 0.0, "fungal spores should be deposited through a distinct dispersal interaction")
	_assert(ecology.resource_amount(engineer_cell, "dam_material") > 0.0, "engineer should turn gathered biomass into a water-retaining dam")
	_assert(simulation.conservation_violations.is_empty(), "shared authority should not report impossible transfers")
	var taxonomies: Array = simulation.event_history.map(func(event: Dictionary): return event["taxonomy"])
	_assert("organism.detritus_recycled" in taxonomies, "colony effect should be recorded")
	_assert("organism.patch_pollinated" in taxonomies, "vector effect should be recorded")
	_assert("organism.fungal_spores_distributed" in taxonomies, "fungal dispersal should not be mislabeled as pollination")
	_assert("organism.material_deposited" in taxonomies, "engineer construction should be recorded")
	print("PASS: colony, flying vector, and wetland engineer create distinct ecosystem effects through shared animal authority")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("FAIL: " + message)
	quit(1)
