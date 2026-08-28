extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.astronaut.position = Vector3(18.0, 0.0, 12.0)
	scene.exposure = 0.0
	scene.hunger = 0.0
	scene._update_exposure(100.0)
	if not is_equal_approx(scene.exposure, 10.5):
		_fail("exposed accumulation is not one quarter of the previous rate: %f" % scene.exposure)
		return
	scene.hunger = 3.0
	var eight_field_hours_real_seconds: float = (8.0 * 60.0 * 60.0) / scene.FIELD_TIME_SCALE
	scene._update_hunger(eight_field_hours_real_seconds)
	if not is_equal_approx(scene.hunger, 48.0):
		_fail("hunger does not add one meal threshold over eight field hours: %f" % scene.hunger)
		return
	scene.astronaut.position = Vector3(-5.4, 0.0, -3.1)
	var sheltered_exposure: float = scene.exposure
	var sheltered_hunger: float = scene.hunger
	scene._update_exposure(100.0)
	scene._update_hunger(100.0)
	if scene.exposure != sheltered_exposure or scene.hunger != sheltered_hunger:
		_fail("Wreck Shelter no longer pauses survival accumulation")
		return
	print("PASS: exposure lasts four times longer and hunger supports roughly three meals per field day")
	quit(0)

func _fail(message: String) -> void:
	printerr("FAIL: " + message)
	quit(1)
