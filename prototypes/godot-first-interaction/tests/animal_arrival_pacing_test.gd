extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _assert_water_feedback_persists()
	await _assert_colony_wakes_from_a_sleeping_queen()
	if failed:
		quit(1)
	else:
		print("PASS: watering gives immediate local feedback; a sleeping queen stirs, opens her chamber and founds the colony only while nearby fungus holds, and dies if it fails")
		quit(0)


func _assert_water_feedback_persists() -> void:
	var scene = await _new_scene()
	scene.astronaut.position = scene.emergency_cache.position
	scene._update_nearby_interactions()
	scene._interact()
	scene.astronaut.position = scene.patches["hollow"]["node"].position
	scene._update_nearby_interactions()
	scene._water_nearby_patch()
	_assert(scene.status_label.text.contains("no living moss is confirmed yet"), "watering should distinguish an immediate dormant-life response from established growth")
	_assert(scene.scanner_readout.text.contains("LIVING MOSS  not yet confirmed"), "the Field Scanner should expose the immediate local water response")
	_assert(scene.status_hold_timer > 0.0, "the water response should remain readable instead of being overwritten on the next ecology tick")
	scene._set_status("Later ecological evidence")
	_assert(not scene.status_label.text.contains("Later ecological evidence"), "background ecology should not immediately overwrite intervention feedback")
	scene._update_status_hold(3.0)
	_assert(scene.status_label.text.contains("Later ecological evidence"), "queued ecological evidence should appear after the intervention response")
	scene.queue_free()


func _assert_colony_wakes_from_a_sleeping_queen() -> void:
	var scene = await _new_scene()
	_assert(scene.hoodoo_field.queen_cells.size() >= 4, "several hoodoos should hold a sleeping queen")
	var queen: Vector2i = scene.hoodoo_field.queen_cells[0]
	var calls_per_observation: int = scene._calls_per_habitat_observation()
	_advance_search(scene, calls_per_observation * 3)
	_assert(scene.dormant_queens[queen]["state"] == "dormant", "a queen should keep sleeping while no fungus grows near her hoodoo")
	_assert(not scene.animal_simulation.agents.has("colony:1"), "no colony should exist until a queen wakes")

	_seed_patch(scene, queen, {"fungus": 0.2, "dead_biomass": 0.2}, 1)
	_advance_search(scene, calls_per_observation * scene.COLONY_PROSPECTING_OBSERVATIONS)
	scene._update_colony_prospect_visual()
	_assert(scene.dormant_queens[queen]["state"] == "stirring", "living fungus beside the hoodoo should make its queen stir")
	_assert(not scene.animal_simulation.agents.has("colony:1"), "a stirring queen should not yet be a colony")
	_assert(scene.colony_prospect_root.visible, "the stirring queen should be visible at her chamber")
	_assert(scene.colony_prospect_label.text.contains("QUEEN STIRRING"), "the telegraph should say a queen is stirring, not that a nest exists")
	_assert(_has_event(scene.evidence.events, "organism.colony_queen_stirring"), "stirring should be captured as evidence")
	for other in scene.hoodoo_field.queen_cells.slice(1):
		_assert(scene.dormant_queens[other]["state"] == "dormant", "queens far from the fungus should keep sleeping")

	var observations_before_founding: int = int(scene.ARRIVAL_SUPPORT_OBSERVATIONS["colony"]) - int(scene.COLONY_PROSPECTING_OBSERVATIONS) - 1
	_advance_search(scene, calls_per_observation * observations_before_founding)
	scene._update_colony_prospect_visual()
	_assert(not scene.animal_simulation.agents.has("colony:1"), "the colony should still be absent one survey before founding")
	_assert(scene.colony_prospect_label.text.contains("CHAMBER OPENING"), "the opening chamber should make the approaching colony legible")

	_advance_search(scene, calls_per_observation)
	_assert(_is_present(scene, "colony:1"), "fungus held long enough should let the queen found a colony")
	var nest: Vector2i = scene.animal_simulation.agent_state("colony:1")["cell"]
	_assert(maxi(absi(nest.x - queen.x), absi(nest.y - queen.y)) == 1, "the nest should open right beside the queen's hoodoo")
	_assert(scene.dormant_queens[queen]["state"] == "founded", "the founding queen should be recorded")
	var minimum_seconds: float = float(calls_per_observation * int(scene.ARRIVAL_SUPPORT_OBSERVATIONS["colony"])) * scene.ECOLOGY_STEP_SECONDS
	_assert(minimum_seconds > 35.0, "waking should take tens of seconds, not a few")
	scene.queue_free()

	var early_scene = await _new_scene()
	var early_queen: Vector2i = early_scene.hoodoo_field.queen_cells[0]
	_seed_patch(early_scene, early_queen, {"fungus": 0.2}, 1)
	_advance_search(early_scene, calls_per_observation * early_scene.COLONY_PROSPECTING_OBSERVATIONS)
	_assert(early_scene.dormant_queens[early_queen]["state"] == "stirring", "the queen should stir before the fungus fails")
	_clear_patch(early_scene, early_queen, 2)
	_advance_search(early_scene, calls_per_observation)
	early_scene._update_colony_prospect_visual()
	_assert(early_scene.dormant_queens[early_queen]["state"] == "dead", "a queen whose fungus fails while she wakes should die")
	_assert(not early_scene.animal_simulation.agents.has("colony:1"), "a dead queen should leave no colony")
	_assert(not early_scene.colony_prospect_root.visible, "the stirring telegraph should end with the queen")
	_assert(_has_event(early_scene.evidence.events, "organism.colony_queen_died"), "the early waking should be captured as evidence")
	_assert(early_scene.queen_husks.size() == 1, "the dead queen should stay visible at her chamber")
	early_scene.queue_free()


func _new_scene():
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	return scene


func _seed_patch(scene, center: Vector2i, resources: Dictionary, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			scene.ecology.add_resources(Vector2i(x, y), resources)


func _clear_patch(scene, center: Vector2i, radius := 1) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			scene.ecology.consume_resource(Vector2i(x, y), "dead_biomass", 1.0)
			scene.ecology.consume_resource(Vector2i(x, y), "fungus", 1.0)


func _advance_search(scene, calls: int) -> void:
	for ignored in range(calls):
		scene._seed_integrated_animals()


func _is_present(scene, stable_id: String) -> bool:
	var agent: Dictionary = scene.animal_simulation.agent_state(stable_id)
	return not agent.is_empty() and bool(agent["alive"]) and bool(agent.get("present", true))


func _has_event(events: Array[Dictionary], taxonomy: String) -> bool:
	for event in events:
		if String(event["taxonomy"]) == taxonomy:
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("FAIL: " + message)
	failed = true
