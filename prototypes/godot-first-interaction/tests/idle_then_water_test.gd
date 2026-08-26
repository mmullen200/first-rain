extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	# Reproduce the captured play session: the unopened scene sat at tick 480
	# before the astronaut began the first Field Experiment.
	for ignored in range(480):
		scene._update_ecology_grid(scene.ECOLOGY_STEP_SECONDS)

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
		printerr("FAIL: an idle opening made the sheltered intervention incapable of awakening the grazer: ", scene.ecology.summary())
		quit(1)
		return
	print("PASS: an idle opening does not alter the dormant ecology; the sheltered intervention awakens the grazer")
	quit(0)
