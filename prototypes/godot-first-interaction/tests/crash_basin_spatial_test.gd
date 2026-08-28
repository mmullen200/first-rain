extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var crossing_seconds: float = Vector2(-5.4, -3.1).distance_to(Vector2(scene.refuge_position.x, scene.refuge_position.z)) / scene.WALK_SPEED
	if crossing_seconds < 25.0 or crossing_seconds > 35.0:
		_fail("wreck-to-downstream traversal is outside the accepted 25–35 second range: %f" % crossing_seconds)
		return
	var expected := {
		Vector3(-5.4, 0.0, -3.1): "WRECK SHELTER",
		Vector3(-2.7, 0.0, -1.55): "SHELTERED HOLLOW",
		Vector3(16.0, 0.0, 3.0): "EXPOSED TOXIC SHELF",
		Vector3(18.0, 0.0, 12.0): "DRY DRAINAGE SPINE",
		Vector3(37.0, 0.0, 23.0): "DOWNSTREAM RECOVERY POCKET"
	}
	for position in expected:
		scene.astronaut.position = position
		if scene._current_zone() != expected[position]:
			_fail("zone landmark did not resolve to " + expected[position])
			return
		scene.visited_zones[scene._current_zone()] = true
	var survey: String = scene._basin_survey_text()
	if survey.contains("?????") or not survey.contains("No route or objective is inferred"):
		_fail("Basin Survey did not preserve visited zones without route guidance")
		return

	var source := Vector2i(5, 5)
	var downstream := Vector2i(5, 6)
	var before: float = scene.ecology.cell_snapshot(downstream.x, downstream.y)["moisture"]
	scene.ecology.add_water(scene.ecology.world_position(source.x, source.y), 1.0, 0.5)
	scene.ecology.step()
	var after: float = scene.ecology.cell_snapshot(downstream.x, downstream.y)["moisture"]
	if after <= before:
		_fail("a real upstream water input did not create a downhill Drainage Pulse")
		return
	print("PASS: connected zones, traversal scale, Basin Survey, and episodic downhill drainage match the spatial contract")
	quit(0)

func _fail(message: String) -> void:
	printerr("FAIL: " + message)
	quit(1)
