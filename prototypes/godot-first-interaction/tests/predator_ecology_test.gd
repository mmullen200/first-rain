extends SceneTree

const Grid = preload("res://ecology_grid.gd")
const Animals = preload("res://animal_simulation.gd")
var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_attempts_and_fear()
	_test_terrain_distribution()
	_test_scavenging()
	_test_territories()
	_test_replay()
	await _test_playable_fixture()
	if not failed:
		print("PASS: fallible terrain-dependent hunts, failed-attempt cost/fear/escape, finite scavenging, exclusive territories and replay")
	quit(1 if failed else 0)


func _pair(rng := 12345):
	var grid = Grid.new()
	grid.canopy.fill(0.0)
	grid.rhizome.fill(0.0)
	grid.dead_biomass.fill(0.0)
	grid.toxicity.fill(0.0)
	var simulation = Animals.new(grid, 73)
	simulation.register_agent("predator", "predator:1", {"cell": Vector2i(6, 8), "hunt_rng": rng})
	simulation.register_agent("grazer", "grazer:1", {"cell": Vector2i(7, 8)})
	return simulation


func _test_attempts_and_fear() -> void:
	var simulation = _pair()
	var before: Dictionary = simulation.agent_state("predator:1")
	simulation._predate("predator:1", "grazer:1", 0.16)
	var prey: Dictionary = simulation.agent_state("grazer:1")
	var predator: Dictionary = simulation.agent_state("predator:1")
	_assert(_count(simulation, "organism.hunt_attempted") == 1, "missing hunt attempt")
	_assert(_count(simulation, "organism.predation") == 0, "known failed draw unexpectedly landed")
	_assert(prey["body_biomass"] == 1.0 and prey["fear"] > 0.8, "miss must spare prey biomass and frighten it")
	_assert(is_equal_approx(before["energy"] - predator["energy"], Animals.HUNT_ENERGY_COST), "miss did not spend energy")
	_assert(predator["hunt_cooldown"] == Animals.HUNT_RECOVERY_TICKS, "miss did not impose recovery")
	simulation._predate("predator:1", "grazer:1", 0.16)
	_assert(_count(simulation, "organism.hunt_attempted") == 1, "same-tick retries bypass recovery")
	var original_cell: Vector2i = prey["cell"]
	simulation.ecology.add_resources(original_cell, {"moss": 0.8})
	var choice: Dictionary = simulation._choose_grazer_intention(prey)
	_assert(choice["type"] == "move", "frightened hungry grazer kept feeding")
	if choice["type"] == "move":
		_assert(Vector2(choice["cell"]).distance_to(Vector2(predator["cell"])) > Vector2(original_cell).distance_to(Vector2(predator["cell"])), "escape did not increase separation")
		simulation._resolve_intention(choice)
	for ignored in range(10):
		var events: Array[Dictionary] = simulation.step()
		for event in events:
			_assert(event["taxonomy"] not in ["organism.moss_consumed", "organism.rhizome_consumed"], "fear did not suppress grazing after an unsuccessful attempt")
	_assert(_count(simulation, "organism.hunt_attempted") == 1, "recovery allowed rapid repeated hunts")
	var success = _pair(1)
	success._predate("predator:1", "grazer:1", 0.16)
	_assert(_count(success, "organism.predation") == 1, "known successful draw did not transfer prey")
	_assert(is_equal_approx(success.agent_state("grazer:1")["body_biomass"], 0.84), "successful hunt transferred wrong amount")
	_assert(is_equal_approx(success.agent_state("predator:1")["carried_material"].get("animal_biomass", 0.0), 0.16), "prey material not retained in predator")
	_assert(success.agent_state("grazer:1")["fear"] > 0.8, "successful attempt omitted fear")
	var out_of_range = _pair(1)
	out_of_range.agents["grazer:1"]["cell"] = Vector2i(20, 8)
	out_of_range._predate("predator:1", "grazer:1", 0.16)
	_assert(_count(out_of_range, "organism.hunt_attempted") == 0, "resolution attacked distant prey")


func _test_terrain_distribution() -> void:
	var counts: Array[int] = []
	for cover in [0.0, 1.0]:
		var simulation = _pair(12345)
		simulation.ecology.canopy.fill(cover)
		# Independent, recovered encounters reuse identical random draws in
		# paired terrain treatments, isolating terrain from prey movement.
		for ignored in range(1000):
			simulation.agents["predator:1"]["energy"] = 1.0
			simulation.agents["predator:1"]["hunger"] = 1.0
			simulation.agents["predator:1"]["hunt_cooldown"] = 0
			simulation.agents["grazer:1"]["body_biomass"] = 1.0
			simulation._predate("predator:1", "grazer:1", 0.16)
		counts.append(_count(simulation, "organism.predation"))
	_assert(counts[0] > 50 and counts[0] < 160, "open-ground successes outside broad expected range")
	_assert(counts[1] > 300 and counts[1] < 500 and counts[1] > counts[0], "cover did not materially help ambusher while retaining failures")
	print("Terrain experiment: ", counts[0], "/1000 open, ", counts[1], "/1000 full cover")


func _test_scavenging() -> void:
	var simulation = _pair()
	simulation.set_agent_presence("grazer:1", false)
	var cell := Vector2i(6, 8)
	simulation.ecology.add_resources(cell, {"dead_biomass": 0.3})
	var amount_before: float = simulation.ecology.resource_amount(cell, "dead_biomass")
	var hunger_before: float = simulation.agent_state("predator:1")["hunger"]
	var choice: Dictionary = simulation._choose_predator_intention(simulation.agent_state("predator:1"))
	_assert(choice["type"] == "consume", "predator without live prey did not scavenge")
	simulation._resolve_intention(choice)
	var predator: Dictionary = simulation.agent_state("predator:1")
	var food: float = predator["carried_material"].get("dead_biomass", 0.0)
	_assert(is_equal_approx(amount_before - simulation.ecology.resource_amount(cell, "dead_biomass"), food), "scavenging created food")
	_assert(predator["hunger"] < hunger_before and food > 0.0, "scavenging failed to nourish predator")
	var minerals_before: float = simulation.ecology.resource_amount(cell, "nutrients")
	# Advance animal metabolism with a frozen grid to isolate transfers.
	for ignored in range(34):
		simulation._resolve_intention(simulation._choose_predator_intention(simulation.agent_state("predator:1")))
	_assert(is_equal_approx(simulation.ecology.resource_amount(cell, "nutrients") - minerals_before, food), "digested material did not return to nutrient cycle")
	_assert(_count(simulation, "organism.scavenged") == 1, "scavenging did not respect digestive pause")
	_assert(simulation.conservation_violations.is_empty(), "scavenging transfer drift")


func _test_territories() -> void:
	var simulation = _pair()
	_assert(not simulation.register_agent("predator", "predator:blocked", {"cell": Vector2i(10, 8)}), "overlapping territory was admitted")
	_assert(simulation.register_agent("predator", "predator:2", {"cell": Vector2i(17, 8)}), "separate territory was refused")
	simulation.submit_intervention({"type": "relocate", "agent_id": "predator:2", "cell": Vector2i(7, 8)})
	simulation._resolve_interventions()
	_assert(simulation.agent_state("predator:2")["habitat_cell"] == Vector2i(17, 8), "relocation bypassed ownership")
	simulation.set_agent_presence("predator:2", false)
	_assert(not simulation.set_agent_presence("predator:2", true, Vector2i(7, 8)), "return bypassed occupied territory")
	_assert(simulation.set_agent_presence("predator:2", true, Vector2i(17, 8)), "valid return failed")
	simulation._move_agent("predator:1", Vector2i(17, 8))
	_assert(simulation.agent_state("predator:1")["cell"] == Vector2i(6, 8), "movement bypassed territory")
	simulation.agents["grazer:1"]["cell"] = Vector2i(11, 8)
	_assert(simulation._predator_prey_id(simulation.agent_state("predator:1")).is_empty(), "predator selected prey beyond territory")
	simulation.set_agent_presence("predator:1", false)
	_assert(simulation.predator_territory_available(Vector2i(6, 8)), "departure failed to release territory")
	_assert(simulation.register_agent("predator", "predator:replacement", {"cell": Vector2i(6, 8)}), "vacated territory could not be occupied")
	simulation.submit_intervention({"type": "injure", "agent_id": "predator:replacement", "amount": 1.0})
	simulation._resolve_interventions()
	_assert(simulation.predator_territory_available(Vector2i(6, 8)), "death failed to release territory")
	for ignored in range(150):
		simulation.step()
		var predator: Dictionary = simulation.agent_state("predator:2")
		_assert(simulation._cell_distance(predator["cell"], predator["habitat_cell"]) <= Animals.PREDATOR_TERRITORY_RADIUS, "autonomous patrol escaped territory")


func _test_replay() -> void:
	var simulation = _pair()
	simulation._predate("predator:1", "grazer:1", 0.16)
	var initial: Dictionary = simulation.snapshot()
	for ignored in range(180):
		simulation.step()
	var replay = Animals.new(Grid.new(), 999)
	_assert(replay.restore(initial), "predator snapshot rejected")
	for ignored in range(180):
		replay.step()
	_assert(replay.snapshot() == simulation.snapshot(), "hunt randomness, fear, energy, gut or territory lost on replay")


func _count(simulation, taxonomy: String) -> int:
	var count := 0
	for event in simulation.event_history:
		if event["taxonomy"] == taxonomy:
			count += 1
	return count


func _test_playable_fixture() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene._seed_predator_fixture()
	_assert(scene.animal_simulation.agent_state("predator:2")["present"], "fixture lacks second separated predator")
	_assert(scene._best_predator_arrival_habitat().is_empty(), "occupied grazer ranges advertised another predator site")
	for ignored in range(80):
		scene._update_ecology_grid(scene.ECOLOGY_STEP_SECONDS)
	_assert(_count(scene.animal_simulation, "organism.hunt_attempted") > 0, "living fixture never presents a hunt")
	_assert(_count(scene.animal_simulation, "organism.scavenged") > 0, "living fixture never presents scavenging")
	_assert(scene.predator_tracks.has("predator:1") and scene.predator_tracks.has("predator:2"), "fixture omits visible territorial activity")
	_assert(scene.animal_markers["predator:1"].visible and scene.animal_markers["predator:2"].visible, "fixture predators departed before observation")
	scene.queue_free()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL: " + message)
