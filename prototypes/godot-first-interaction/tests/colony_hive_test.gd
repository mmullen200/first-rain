extends SceneTree

const EcologyGrid = preload("res://ecology_grid.gd")
const AnimalSimulation = preload("res://animal_simulation.gd")

var failed := false


func _init() -> void:
	var ecology = EcologyGrid.new()
	var simulation = AnimalSimulation.new(ecology, 41)
	var hive_cell := Vector2i(4, 4)
	var forage_cell := Vector2i(8, 4)
	ecology.add_resources(forage_cell, {"moss": 0.42, "rhizome": 0.42})
	_assert(simulation.register_agent("colony", "colony:1", {"cell": hive_cell, "hunger": 0.9}), "colony registration failed")
	var initial_plant: float = ecology.resource_amount(forage_cell, "moss") + ecology.resource_amount(forage_cell, "rhizome")
	var worker_left_hive := false
	var home_stayed_fixed := true
	var hive_marker_stayed_fixed := true
	for ignored in range(220):
		simulation.step()
		var state: Dictionary = simulation.agent_state("colony:1")
		home_stayed_fixed = home_stayed_fixed and state.get("home_cell", Vector2i(-1, -1)) == hive_cell
		hive_marker_stayed_fixed = hive_marker_stayed_fixed and state["cell"] == hive_cell
		for worker in state["workers"]:
			if worker["cell"] != hive_cell:
				worker_left_hive = true
	_assert(home_stayed_fixed, "the colony should retain one fixed hive cell")
	_assert(hive_marker_stayed_fixed, "the colony marker should remain at its hive instead of roaming")
	_assert(worker_left_hive, "the hive should send a worker toward plant matter")
	_assert(_has_event(simulation.event_history, "organism.colony_plant_gathered"), "a worker never gathered a small amount of plant matter")
	_assert(_has_event(simulation.event_history, "organism.colony_plant_returned"), "a worker never returned plant matter to the hive")
	_assert(ecology.resource_amount(forage_cell, "moss") + ecology.resource_amount(forage_cell, "rhizome") < initial_plant, "worker foraging did not remove plant matter from the source patch")
	_assert(ecology.resource_amount(hive_cell, "dead_biomass") > 0.0 or _has_event(simulation.event_history, "organism.detritus_recycled"), "returned plant matter never reached the hive economy")
	_assert(simulation.conservation_violations.is_empty(), "colony worker transport violated material conservation")
	if failed:
		quit(1)
	else:
		print("PASS: a fixed eusocial hive sends slow workers to gather small plant loads and return them home")
		quit(0)


func _has_event(events: Array[Dictionary], taxonomy: String) -> bool:
	for event in events:
		if event["taxonomy"] == taxonomy:
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("FAIL: " + message)
	failed = true
