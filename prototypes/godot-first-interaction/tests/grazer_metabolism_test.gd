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

	var saw_seeking := false
	var saw_digesting := false
	var saw_roaming := false
	for ignored in range(600):
		scene._update_ecology_grid(0.1)
		scene._update_grazer(0.1)
		scene._update_interface()
		saw_seeking = saw_seeking or "GRAZER seeking" in scene.ecosystem_label.text
		saw_digesting = saw_digesting or "GRAZER digesting" in scene.ecosystem_label.text
		saw_roaming = saw_roaming or "GRAZER roaming" in scene.ecosystem_label.text

	var recorded_manure := false
	for discovery in scene.discoveries:
		if discovery.begins_with("Grazer manure"):
			recorded_manure = true
			break
	if not (saw_seeking and saw_digesting and saw_roaming and recorded_manure):
		printerr("FAIL: grazer did not expose a complete metabolic cycle; seeking=", saw_seeking, " digesting=", saw_digesting, " roaming=", saw_roaming, " manure=", recorded_manure)
		quit(1)
		return
	print("PASS: grazer exposes seeking, digestion, roaming, and manure deposition")
	quit(0)
