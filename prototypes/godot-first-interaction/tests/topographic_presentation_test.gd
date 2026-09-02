extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var model = scene.ecology
	var catchment: Vector2i = model.HIGH_CATCHMENT_CELL
	var index: int = catchment.y * model.WIDTH + catchment.x
	var world: Vector2 = model.world_position(catchment.x, catchment.y)
	var height: float = model.terrain_height(catchment)
	var block: MeshInstance3D = scene.ecology_cells[index]
	_assert(block.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "terrain blocks should cast height-revealing shadows")
	_assert(is_equal_approx(block.position.y, height * 0.5), "each block should extend from its terrain height down to the floor")

	model.canopy[index] = 0.02
	model.surface_water[index] = 0.25
	scene._refresh_ecology_visuals()
	_assert(scene.canopy_meshes[index].visible, "canopy should stand above the terrain on its own mesh")
	_assert(is_equal_approx(scene.ecology_cells[index].scale.y, 1.0), "vegetation should not stretch terrain vertically")
	_assert(scene.water_meshes[index].visible and scene.water_meshes[index].position.y > height, "standing water should be a separate level surface above the step")

	scene.astronaut.position = Vector3(world.x, height, world.y)
	scene.scanner_recovered = true
	scene._toggle_analysis_lens()
	scene._toggle_analysis_lens()
	_assert(scene.analysis_lens_mode == 2, "the Field Scanner should expose a third elevation-and-flow mode")
	_assert(scene.flow_arrows[index].visible, "the terrain lens should show a local downhill arrow")
	scene._move_astronaut(0.0)
	_assert(is_equal_approx(scene.astronaut.position.y, height + 0.02), "the astronaut should stand on the terrain height")

	var before: float = model.terrain_height(catchment)
	scene._excavate_nearby_cell()
	_assert(model.terrain_height(catchment) < before, "the astronaut's excavation should lower the occupied Ecological Cell")

	print("PASS: stepped blocks, shadows, separate canopy and water, terrain lens arrows, and terrain-following astronaut expose the landform")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		quit(1)
