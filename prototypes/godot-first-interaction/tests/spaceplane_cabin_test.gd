extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var plane = scene.spaceplane
	var hatch_z: float = (plane._z_at(float(plane.HATCH_STATIONS.x) / plane.STATIONS) + plane._z_at(float(plane.HATCH_STATIONS.y) / plane.STATIONS)) * 0.5
	var hatch_width: float = plane._half_width(plane._t_at(hatch_z))

	# Walking straight at the hull away from the hatch is blocked by its wall.
	var cockpit_z: float = plane.SEAT_Z
	if await _walk_in(scene, plane, Vector3(plane._half_width(plane._t_at(cockpit_z)) + 0.55, plane.FLOOR_Y, cockpit_z), 60):
		_fail("the astronaut walked through the hull wall instead of the hatch")
		return

	# Walking in through the open hatch enters the cabin and stands on its floor.
	if not await _walk_in(scene, plane, Vector3(hatch_width + 0.55, plane.FLOOR_Y, hatch_z), 240):
		_fail("the astronaut could not walk in through the open hatch")
		return
	var floor_height: float = plane.cabin_point(plane._world_to_body(scene.astronaut.global_position) * Vector3(1.0, 0.0, 1.0) + Vector3(0.0, plane.FLOOR_Y, 0.0)).y
	if absf(scene.astronaut.global_position.y - floor_height) > 0.05:
		_fail("inside the cabin the astronaut does not stand on the floor")
		return
	if not plane.interior_camera.current:
		_fail("the view did not move to the cabin camera inside the spaceplane")
		return
	if not scene._at_wreck():
		_fail("the cabin is not part of the Wreck Shelter")
		return
	if not plane.is_inside(scene.emergency_cache.global_position):
		_fail("the emergency cache is not inside the cabin")
		return

	# At the cockpit, E consults the ship screen and moving steps back.
	scene.astronaut.position = plane.cabin_point(Vector3(0.0, plane.FLOOR_Y, 0.2))
	await physics_frame
	scene._open_emergency_cache()
	scene._interact()
	await physics_frame
	if not scene.consulting_ship_screen or not plane.console_camera.current:
		_fail("E at the cockpit did not bring up the ship screen")
		return
	_press(KEY_S, true)
	for i in range(3):
		await physics_frame
	_press(KEY_S, false)
	if scene.consulting_ship_screen:
		_fail("moving did not step back from the ship screen")
		return
	print("PASS: the spaceplane cabin is entered through its hatch, shelters the astronaut, holds the cache, and shows the ship screen")
	quit(0)


# Places the astronaut outside the hull at a point given in the cabin's model
# coordinates, then holds the movement key that points most directly inward
# for up to the given number of physics frames.
func _walk_in(scene, plane, start: Vector3, frames: int) -> bool:
	scene.astronaut.position = plane.cabin_point(start)
	await physics_frame
	var outward: Vector3 = plane.cabin_point(start + Vector3(1.0, 0.0, 0.0)) - plane.cabin_point(start)
	var inward := Vector2(-outward.x, -outward.z).normalized()
	var keys := {KEY_W: Vector2(0.0, -1.0), KEY_S: Vector2(0.0, 1.0), KEY_A: Vector2(-1.0, 0.0), KEY_D: Vector2(1.0, 0.0)}
	var best := KEY_W
	for candidate in keys:
		if inward.dot(keys[candidate]) > inward.dot(keys[best]):
			best = candidate
	_press(best, true)
	var entered := false
	for i in range(frames):
		await physics_frame
		if plane.is_inside(scene.astronaut.global_position):
			entered = true
			break
	_press(best, false)
	await physics_frame
	return entered


func _press(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _fail(message: String) -> void:
	printerr("FAIL: " + message)
	quit(1)
