extends SceneTree

const EcologyGrid = preload("res://ecology_grid.gd")
const AnimalSimulation = preload("res://animal_simulation.gd")


func _init() -> void:
	var ecology = EcologyGrid.new()
	var forage_cell := Vector2i(6, 6)
	ecology.add_resources(forage_cell, {"moss": 0.8})
	var simulation = AnimalSimulation.new(ecology, 73)
	_assert(simulation.register_agent("grazer", "grazer:1", {"cell": forage_cell}), "grazer registration failed")
	_assert(not simulation.register_agent("grazer", "grazer:1", {"cell": forage_cell}), "duplicate stable ID was accepted")

	var initial := simulation.snapshot()
	for ignored in range(14):
		simulation.step()
	var expected := simulation.snapshot()
	_assert(_has_event(simulation.event_history, "organism.moss_consumed"), "grazer never consumed environmental biomass")
	_assert(_has_event(simulation.event_history, "organism.material_deposited"), "grazer never deposited digested material away from forage")
	_assert(simulation.conservation_violations.is_empty(), "grazer transfer violated material conservation")

	var replay = AnimalSimulation.new(EcologyGrid.new(), 1)
	_assert(replay.restore(initial), "versioned simulation snapshot did not restore")
	for ignored in range(14):
		replay.step()
	_assert(replay.snapshot() == expected, "stable-ID agents did not replay deterministically from a full snapshot")

	var grazer_cell: Vector2i = simulation.agent_state("grazer:1")["cell"]
	_assert(simulation.register_agent("predator", "predator:1", {"cell": grazer_cell, "hunger": 1.0}), "predator registration failed")
	for ignored in range(10):
		simulation.step()
		if _has_event(simulation.event_history, "organism.predation"):
			break
	_assert(_has_event(simulation.event_history, "organism.predation"), "predator and grazer did not resolve through the shared animal authority")
	_assert(simulation.conservation_violations.is_empty(), "predation violated material conservation")

	_assert(simulation.submit_intervention({"type": "deter", "agent_id": "predator:1", "pressure": 0.8}), "valid astronaut intervention was rejected")
	var intervention_events := simulation.step()
	_assert(_has_event(intervention_events, "intervention.animal_deterred"), "accepted intervention did not resolve on the authoritative tick")
	_assert(float(simulation.agent_state("predator:1")["fear"]) > 0.0, "deterrence did not change authoritative animal state")

	var shade_world := ecology.world_position(4, 4)
	ecology.place_equipment_shade(shade_world)
	var shaded_snapshot := simulation.snapshot()
	var shaded_replay = AnimalSimulation.new(EcologyGrid.new(), 1)
	_assert(shaded_replay.restore(shaded_snapshot), "snapshot with placed ecological infrastructure did not restore")
	_assert(shaded_replay.snapshot() == shaded_snapshot, "full snapshot omitted placed ecological infrastructure state")

	print("PASS: authoritative animal simulation resolves two species, environment transfers, interventions, snapshots, replay, events, and conservation")
	quit(0)


func _has_event(events: Array[Dictionary], taxonomy: String) -> bool:
	for event in events:
		if event["taxonomy"] == taxonomy:
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	printerr("FAIL: " + message)
	quit(1)
