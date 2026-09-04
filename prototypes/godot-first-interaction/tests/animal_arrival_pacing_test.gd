extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _assert_water_feedback_persists()
	await _assert_colony_is_telegraphed_before_settlement()
	if failed:
		quit(1)
	else:
		print("PASS: watering gives immediate local feedback and sustained colony prospecting precedes any anthill")
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


func _assert_colony_is_telegraphed_before_settlement() -> void:
	var scene = await _new_scene()
	var colony_patch := Vector2i(21, 13)
	_seed_patch(scene, colony_patch, {"dead_biomass": 0.2}, 1)
	var calls_per_observation: int = ceili(float(scene.ecology.WIDTH * scene.ecology.HEIGHT) / 24.0)
	_advance_search(scene, calls_per_observation * scene.COLONY_PROSPECTING_OBSERVATIONS)
	scene._update_ecological_animal_markers()
	_assert(not scene.animal_simulation.agents.has("colony:1"), "initial scout observations must not create an anthill")
	_assert(scene.colony_prospect_root.visible, "repeated scouts should visibly telegraph a possible colony site")
	_assert(scene.colony_prospect_label.text.contains("NO NEST"), "the telegraph should clearly distinguish prospecting from an established nest")
	_assert(_has_event(scene.evidence.events, "organism.colony_prospecting"), "prospecting should be captured as evidence before settlement")

	var observations_before_settlement: int = int(scene.ARRIVAL_SUPPORT_OBSERVATIONS["colony"]) - int(scene.COLONY_PROSPECTING_OBSERVATIONS) - 1
	_advance_search(scene, calls_per_observation * observations_before_settlement)
	scene._update_ecological_animal_markers()
	_assert(not scene.animal_simulation.agents.has("colony:1"), "the anthill should still be absent one sustained survey before settlement")
	_assert(scene.colony_prospect_label.text.contains("GROUND DISTURBED"), "later prospecting should make the approaching settlement more legible")

	_advance_search(scene, calls_per_observation)
	_assert(_is_present(scene, "colony:1"), "continuously suitable habitat should eventually support a fixed anthill")
	var minimum_seconds: float = float(calls_per_observation * int(scene.ARRIVAL_SUPPORT_OBSERVATIONS["colony"])) * scene.ECOLOGY_STEP_SECONDS
	_assert(minimum_seconds > 35.0, "colony persistence should represent tens of seconds, not a few seconds")
	scene.queue_free()

	var cancelled_scene = await _new_scene()
	_seed_patch(cancelled_scene, colony_patch, {"dead_biomass": 0.2}, 1)
	_advance_search(cancelled_scene, calls_per_observation * cancelled_scene.COLONY_PROSPECTING_OBSERVATIONS)
	_clear_patch(cancelled_scene, colony_patch)
	_advance_search(cancelled_scene, calls_per_observation)
	cancelled_scene._update_ecological_animal_markers()
	_assert(not cancelled_scene.animal_simulation.agents.has("colony:1"), "lost habitat should cancel prospecting without leaving an anthill")
	_assert(not cancelled_scene.colony_prospect_root.visible, "scout activity should visibly fade when the candidate site fails")
	_assert(_has_event(cancelled_scene.evidence.events, "organism.colony_prospecting_ended"), "cancelled prospecting should be captured as ecological evidence")
	cancelled_scene.queue_free()


func _new_scene():
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	return scene


func _seed_patch(scene, center: Vector2i, resources: Dictionary, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			scene.ecology.add_resources(Vector2i(x, y), resources)


func _clear_patch(scene, center: Vector2i) -> void:
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			scene.ecology.consume_resource(Vector2i(x, y), "dead_biomass", 1.0)


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
