extends SceneTree

const Stoneback = preload("res://stoneback.gd")
const STEP := 1.0 / 60.0

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var marker := Node3D.new()
	root.add_child(marker)
	var animal = Stoneback.new()
	marker.add_child(animal)
	await process_frame

	for ignored in 120:
		animal.animate(STEP, "digesting")
	var resting_shell: float = animal.body.position.y

	# Walk at the grazer's ordinary pace and follow every planted foot.
	var planted := {}
	var worst_slip := 0.0
	var steps_taken := 0
	for frame in 360:
		marker.position.z += 0.38 * STEP
		animal.animate(STEP, "roaming")
		if frame < 120:
			continue
		for leg in animal.legs:
			var foot: Vector3 = leg.get_child(1).global_transform * Vector3(0.0, 0.0, -1.0)
			if foot.y < 0.002:
				if planted.has(leg):
					worst_slip = maxf(worst_slip, Vector2(foot.x, foot.z).distance_to(planted[leg]))
				else:
					planted[leg] = Vector2(foot.x, foot.z)
					steps_taken += 1
			else:
				planted.erase(leg)
	var walking_shell: float = animal.body.position.y
	_assert(steps_taken >= 18, "six legs should keep stepping while walking (%d steps)" % steps_taken)
	_assert(worst_slip < 0.012, "a planted foot should hold its place on the ground (slipped %.3f m)" % worst_slip)
	_assert(walking_shell > resting_shell + 0.04, "walking should lift the shell clear of the ground (%.3f vs %.3f resting)" % [walking_shell, resting_shell])

	for ignored in 90:
		marker.position.z += 1.8 * STEP
		animal.animate(STEP, "fleeing")
	_assert(animal.body.position.y > walking_shell, "fleeing should lift the shell higher than walking")
	for stalk in animal.stalks:
		_assert(stalk.rotation.x < -0.8, "fleeing should lay the eye stalks back")

	for ignored in 120:
		animal.animate(STEP, "feeding")
	_assert(animal.body.rotation.x > 0.1, "feeding should tip the shell nose-down over the forage")

	animal.set_juvenile(true)
	_assert(animal.scale.x < 0.8, "a juvenile should be smaller")

	if failed:
		quit(1)
	else:
		print("PASS: the stoneback steps without skating (worst slip %.4f m over %d steps), lifts its shell to walk and higher to flee, lays its eye stalks back when fleeing, dips to feed, and draws juveniles smaller" % [worst_slip, steps_taken])
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL: ", message)
