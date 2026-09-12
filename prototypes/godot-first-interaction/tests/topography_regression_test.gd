extends SceneTree

const EcologyGridModel = preload("res://ecology_grid.gd")
var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ecology = EcologyGridModel.new()
	var unintended_sinks := 0
	for y in range(EcologyGridModel.HEIGHT):
		for x in range(EcologyGridModel.WIDTH):
			var cell := Vector2i(x, y)
			if ecology.downhill_neighbor(cell) == cell and cell != EcologyGridModel.CLOSED_HOLLOW_CELL:
				unintended_sinks += 1
	_assert(unintended_sinks <= EcologyGridModel.WIDTH, "the terrain should not turn most of the basin into closed, water-filling flats")

	for _pulse in range(40):
		ecology.add_water(Vector2(16.0, 10.0), 0.04, 58.0)
		ecology.step()
	var flooded_cells := 0
	for value in ecology.surface_water:
		if value >= 0.04:
			flooded_cells += 1
	_assert(flooded_cells < EcologyGridModel.WIDTH * EcologyGridModel.HEIGHT / 4, "regional rain should drain into landforms instead of coating the entire landscape")

	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var animal_cell := Vector2i(12, 7)
	scene.animal_simulation.register_agent("vector", "vector:1", {"cell": animal_cell})
	for _frame in range(12):
		scene._update_ecological_animal_markers()
	var marker: Node3D = scene.animal_markers["vector:1"]
	_assert(marker.position.y > scene.ecology.terrain_height(animal_cell), "animal markers should move above the terrain instead of underneath it")

	var engineer_start := Vector2i(12, 7)
	var engineer_finish := Vector2i(13, 7)
	scene.animal_simulation.register_agent("wetland_engineer", "engineer:1", {"cell": engineer_start})
	scene._update_ecological_animal_markers()
	var engineer_marker: Node3D = scene.animal_markers["engineer:1"]
	scene.animal_simulation.agents["engineer:1"]["cell"] = engineer_finish
	scene._update_ecological_animal_markers()
	var engineer_before := Vector2(engineer_marker.position.x, engineer_marker.position.z)
	scene._update_ground_animal_markers(0.1)
	var engineer_after := Vector2(engineer_marker.position.x, engineer_marker.position.z)
	var engineer_step := engineer_before.distance_to(engineer_after)
	_assert(engineer_step > 0.0 and engineer_step <= scene.GROUND_ANIMAL_MOVE_SPEED * 0.1 + 0.001, "ground animals should interpolate every frame instead of jumping between Ecological Cells")
	_assert(is_equal_approx(engineer_marker.position.y, scene._terrain_surface_height(engineer_after) + 0.25), "ground animals should follow the continuous presentation surface")

	scene.grazer_awake = true
	scene.animal_simulation.register_agent("grazer", "grazer:1", {"cell": scene.grazer_cell})
	scene._update_grazer(0.2)
	_assert(scene.grazer_target_position.y > scene.ecology.terrain_height(scene.grazer_cell), "the roaming grazer should target the visible terrain surface")

	if failed:
		quit(1)
	else:
		print("PASS: regional rain stays concentrated and moving animals remain above stepped terrain")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL: ", message)
