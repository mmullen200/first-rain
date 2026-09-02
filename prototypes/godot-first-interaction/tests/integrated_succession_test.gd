extends SceneTree

const EcologyGrid = preload("res://ecology_grid.gd")


func _init() -> void:
	var ecology = EcologyGrid.new()
	var cell: Vector2i = EcologyGrid.CLOSED_HOLLOW_CELL
	var world: Vector2 = ecology.world_position(cell.x, cell.y)
	ecology.add_resources(cell, {
		"moss": 0.55,
		"fungus": 0.34,
		"nutrients": 0.82,
		"dormant_rhizome": 0.9,
		"dormant_canopy": 0.8,
		"surface_water": 0.62,
		"aquatic_producer": 0.035
	})
	ecology.add_water(world, 0.95, 3.2)
	for simulation_tick in range(260):
		if simulation_tick in [70, 140, 210]:
			ecology.add_water(world, 0.48, 3.2)
		ecology.step()

	var summary: Dictionary = ecology.summary()
	var sample: Dictionary = ecology.cell_snapshot(cell.x, cell.y)
	_assert(summary["rhizome_cells"] > 0, "pioneer soil did not support a reproducing rooted mat")
	_assert(summary["canopy_cells"] > 0, "rooted/decomposer habitat did not support canopy establishment")
	_assert(summary["aquatic_cells"] > 0, "standing water did not support aquatic production")
	_assert(sample["aquatic_consumer"] > 0.0, "aquatic production did not establish a consumer population")
	_assert(summary["total_volatile_sulfur"] > 0.0, "balanced aquatic metabolism produced no volatile sulfur contribution")
	_assert(sample["ground_bloom"] > 0.0, "rooted plants produced no flowering signal for pollinators")
	_assert(sample["canopy_bloom"] > 0.0, "canopy plants produced no distinct blossom signal")
	_assert(sample["pollination"] == 0.0, "plants should not become pollinated without an animal vector")
	_assert(sample["dissolved_oxygen"] < 0.9 and sample["dissolved_oxygen"] > 0.0, "aquatic oxygen did not respond within physical bounds")

	print("PASS: pioneer soil supports rooted and canopy succession while standing water develops a regulated sulfur-processing food web")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	printerr("FAIL: " + message)
	quit(1)
