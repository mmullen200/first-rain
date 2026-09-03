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
	if scene.ecology.tick != 0:
		printerr("FAIL: an idle opening advanced the dormant ecology before the first Field Experiment")
		quit(1)
		return

	scene.astronaut.position = scene.emergency_cache.position
	scene._update_nearby_interactions()
	scene._interact()
	scene.astronaut.position = scene.patches["hollow"]["node"].position
	scene._update_nearby_interactions()
	scene._water_nearby_patch()

	for ignored in range(180):
		scene._update_ecology_grid(scene.ECOLOGY_STEP_SECONDS)
	var summary: Dictionary = scene.ecology.summary()
	if float(summary["total_moss"]) <= 0.0 or int(summary["fungus_cells"]) < 1:
		printerr("FAIL: an idle opening consumed the sheltered site's pioneer/decomposer response: ", summary)
		quit(1)
		return
	if not scene.animal_simulation.agents.is_empty():
		printerr("FAIL: the first sheltered intervention skipped early Succession and established an animal: ", scene.animal_simulation.agents)
		quit(1)
		return
	print("PASS: an idle opening preserves dormant ecology; the first sheltered intervention awakens early life without skipping to animals")
	quit(0)
