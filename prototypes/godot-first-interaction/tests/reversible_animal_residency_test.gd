extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _assert_vector_needs_flowers_not_colony()
	await _assert_support_is_local()
	await _assert_arrival_and_departure_need_persistence()
	if failed:
		quit(1)
	else:
		print("PASS: animals arrive, leave, and return from sustained local habitat support without a progression checklist")
		quit(0)


func _assert_vector_needs_flowers_not_colony() -> void:
	var scene = await _new_scene()
	var flowers := Vector2i(4, 12)
	scene.ecology.add_resources(flowers, {"ground_bloom": 0.16})
	scene.ecology.add_resources(flowers + Vector2i(2, 0), {"ground_bloom": 0.16})
	_advance_until_present(scene, "vector:1", 96)
	_assert(_is_present(scene, "vector:1"), "sustained separated flowers should support a vector without a colony")
	_assert(not scene.animal_simulation.agents.has("colony:1"), "a vector should not tick a colony prerequisite box")
	scene.queue_free()


func _assert_support_is_local() -> void:
	var scene = await _new_scene()
	var grazer_patch := Vector2i(3, 13)
	_seed_patch(scene, grazer_patch, {"moss": 0.15, "rhizome": 0.15}, 1)
	scene.ecology.add_resources(Vector2i(21, 2), {"canopy": 0.8})
	var channel: Vector2i = scene.ecology.CHANNEL_CELL
	_seed_patch(scene, channel, {"surface_water": 0.18, "rhizome": 0.14}, 1)
	_seed_patch(scene, Vector2i(21, 13), {"aquatic_consumer": 0.2}, 1)
	_advance_arrival_search(scene, 48)
	_assert(not scene.animal_simulation.agents.has("grazer:1"), "distant canopy should not support a grazer's local forage edge")
	_assert(not scene.animal_simulation.agents.has("engineer:1"), "distant aquatic consumers should not support a wetland engineer's local channel")
	scene.queue_free()


func _assert_arrival_and_departure_need_persistence() -> void:
	var scene = await _new_scene()
	var flowers := Vector2i(4, 12)
	_seed_flowers(scene, flowers)
	_advance_arrival_search(scene, 16)
	_clear_flowers(scene, flowers)
	_advance_arrival_search(scene, 20)
	_assert(not scene.animal_simulation.agents.has("vector:1"), "one qualifying observation should not establish a transient vector habitat")

	_seed_flowers(scene, flowers)
	_advance_until_present(scene, "vector:1", 96)
	_assert(_is_present(scene, "vector:1"), "repeated sustained habitat observations should establish the vector")
	_clear_flowers(scene, flowers)
	_advance_arrival_search(scene, scene.DEPARTURE_GRACE_TICKS - 1)
	_assert(_is_present(scene, "vector:1"), "a brief flowering loss should not cause immediate departure")
	_seed_flowers(scene, flowers)
	scene._seed_integrated_animals()
	_assert(_is_present(scene, "vector:1"), "restored local habitat should cancel the departure countdown")

	_clear_flowers(scene, flowers)
	_advance_arrival_search(scene, scene.DEPARTURE_GRACE_TICKS)
	var departed: Dictionary = scene.animal_simulation.agent_state("vector:1")
	_assert(bool(departed["alive"]), "habitat departure should not be recorded as death")
	_assert(not bool(departed["present"]), "sustained local collapse should make the vector leave the basin")
	_assert(_has_event(scene.animal_simulation.event_history, "organism.departed"), "the authoritative animal record should capture departure")

	_seed_flowers(scene, flowers)
	_advance_until_present(scene, "vector:1", 80)
	_assert(_is_present(scene, "vector:1"), "restored sustained flowering should support the vector's return")
	_assert(_has_event(scene.animal_simulation.event_history, "organism.returned"), "the authoritative animal record should capture return")
	scene.queue_free()


func _new_scene():
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	return scene


func _seed_flowers(scene, center: Vector2i) -> void:
	scene.ecology.add_resources(center, {"ground_bloom": 0.16})
	scene.ecology.add_resources(center + Vector2i(2, 0), {"ground_bloom": 0.16})


func _clear_flowers(scene, center: Vector2i) -> void:
	scene.ecology.consume_resource(center, "ground_bloom", 1.0)
	scene.ecology.consume_resource(center + Vector2i(2, 0), "ground_bloom", 1.0)


func _seed_patch(scene, center: Vector2i, resources: Dictionary, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			scene.ecology.add_resources(Vector2i(x, y), resources)


func _advance_arrival_search(scene, attempts: int) -> void:
	for ignored in range(attempts):
		scene._seed_integrated_animals()


func _advance_until_present(scene, stable_id: String, attempts: int) -> void:
	for ignored in range(attempts):
		scene._seed_integrated_animals()
		if _is_present(scene, stable_id):
			return


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
