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
	_seed_grazer_fixture(scene)
	if not scene.grazer_awake:
		printerr("SETUP FAILED: qualifying forage beside canopy did not establish the grazer")
		quit(2)
		return

	var saw_seeking := false
	var saw_digesting := false
	var saw_roaming := false
	for ignored in range(600):
		scene._update_ecology_grid(0.1)
		scene._update_grazer(0.1)
		saw_seeking = saw_seeking or scene.grazer_state == "seeking"
		saw_digesting = saw_digesting or scene.grazer_state == "digesting"
		saw_roaming = saw_roaming or scene.grazer_state == "roaming"

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


func _seed_grazer_fixture(scene) -> void:
	var center := Vector2i(3, 13)
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			scene.ecology.add_resources(Vector2i(x, y), {"moss": 0.15, "rhizome": 0.15})
	scene.ecology.add_resources(center + Vector2i(2, 0), {"canopy": 0.22})
	var habitat: Dictionary = scene._best_arrival_habitat("grazer")
	if not habitat.is_empty():
		scene._awaken_first_grazer(habitat)
