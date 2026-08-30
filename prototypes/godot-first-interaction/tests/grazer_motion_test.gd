extends SceneTree

const EcologyGrid = preload("res://ecology_grid.gd")
const AnimalSimulation = preload("res://animal_simulation.gd")


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

	# Directional persistence now belongs to the authoritative pure-data module.
	var roam_origin := Vector2i(10, 8)
	var motion_simulation = AnimalSimulation.new(EcologyGrid.new(), 41)
	motion_simulation.register_agent("grazer", "grazer:test", {"cell": roam_origin, "hunger": 0.0})
	var previous_cell := roam_origin
	var previous_heading := Vector2i.ZERO
	var straight_run := 0
	var longest_straight_run := 0
	var move_count := 0
	for ignored in range(90):
		var events := motion_simulation.step()
		for event in events:
			if event["taxonomy"] != "organism.moved" or event["subject"] != "grazer:test":
				continue
			var next_cell: Vector2i = event["facts"]["to"]
			var heading := next_cell - previous_cell
			if heading == previous_heading:
				straight_run += 1
			else:
				straight_run = 1
				previous_heading = heading
			longest_straight_run = maxi(longest_straight_run, straight_run)
			previous_cell = next_cell
			move_count += 1
		if move_count >= 4:
			break
	var directional_displacement := Vector2(roam_origin).distance_to(Vector2(previous_cell))
	if longest_straight_run < 3 or directional_displacement < 3.0:
		printerr("FAIL: grazer roam targets curl locally instead of holding a direction; longest-run=", longest_straight_run, " displacement-cells=", directional_displacement)
		quit(1)
		return
	var start: Vector3 = scene.grazer_root.position
	var previous := start
	var largest_step := 0.0
	var moving_frames := 0
	for ignored in range(80):
		scene._update_ecology_grid(0.1)
		scene._update_grazer(0.1)
		var step_distance := Vector2(previous.x, previous.z).distance_to(Vector2(scene.grazer_root.position.x, scene.grazer_root.position.z))
		largest_step = maxf(largest_step, step_distance)
		if step_distance > 0.001:
			moving_frames += 1
		previous = scene.grazer_root.position
	var finish: Vector3 = scene.grazer_root.position
	var displacement := Vector2(start.x, start.z).distance_to(Vector2(finish.x, finish.z))
	if displacement < 0.5 or largest_step > 0.055 or moving_frames < 20:
		printerr("FAIL: grazer motion was not slow, smooth, and visible; displacement=", displacement, " largest-step=", largest_step, " moving-frames=", moving_frames)
		quit(1)
		return
	print("PASS: the awakened grazer holds a roaming direction and travels smoothly; longest-run=", longest_straight_run, " displacement=", displacement, " largest-step=", largest_step, " moving-frames=", moving_frames)
	quit(0)
