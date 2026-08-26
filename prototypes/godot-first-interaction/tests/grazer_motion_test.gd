extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.astronaut.position = scene.emergency_cache.position
	scene._update_nearby_interactions()
	scene._interact()
	scene.astronaut.position = scene.patches["hollow"]["node"].position
	scene._update_nearby_interactions()
	scene._water_nearby_patch()

	for ignored in range(180):
		scene._update_ecology_grid(scene.ECOLOGY_STEP_SECONDS)
		scene._update_grazer(scene.ECOLOGY_STEP_SECONDS)
		if scene.grazer_awake:
			break
	if not scene.grazer_awake:
		printerr("SETUP FAILED: sheltered cultivation did not awaken the grazer")
		quit(2)
		return

	var start: Vector3 = scene.grazer_root.position
	for ignored in range(80):
		scene._update_ecology_grid(0.1)
		scene._update_grazer(0.1)
	var finish: Vector3 = scene.grazer_root.position
	var displacement := Vector2(start.x, start.z).distance_to(Vector2(finish.x, finish.z))
	if displacement < 0.5:
		printerr("FAIL: the awakened grazer did not visibly travel toward viable moss; displacement=", displacement)
		quit(1)
		return
	print("PASS: the awakened grazer visibly travels toward viable moss; displacement=", displacement)
	quit(0)
