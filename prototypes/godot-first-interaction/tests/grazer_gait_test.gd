extends SceneTree

const GrazerFigure = preload("res://grazer_figure.gd")
const STEP := 1.0 / 60.0

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var marker := Node3D.new()
	root.add_child(marker)
	var animal = GrazerFigure.new()
	marker.add_child(animal)
	await process_frame

	# Walk at the grazer's ordinary pace and follow every planted foot.
	var planted := {}
	var worst_slip := 0.0
	var steps_taken := 0
	var fewest_planted := 4
	for frame in 480:
		marker.position.z += 0.38 * STEP
		animal.animate(STEP, "roaming")
		if frame < 120:
			continue
		var down := 0
		for index in animal.feet.size():
			var foot: Vector3 = animal.feet[index].global_position
			if foot.y < 0.03:
				down += 1
				if planted.has(index):
					worst_slip = maxf(worst_slip, Vector2(foot.x, foot.z).distance_to(planted[index]))
				else:
					planted[index] = Vector2(foot.x, foot.z)
					steps_taken += 1
			else:
				planted.erase(index)
		fewest_planted = mini(fewest_planted, down)
	var walking_head: float = animal.head.global_position.y
	_assert(steps_taken >= 12, "all four legs should keep stepping while walking (%d steps)" % steps_taken)
	_assert(worst_slip < 0.012, "a planted foot should hold its place on the ground (slipped %.3f m)" % worst_slip)
	_assert(fewest_planted >= 2, "a heavy walker should never have more than two feet off the ground (%d planted)" % fewest_planted)
	_assert(walking_head < 0.45, "the neck should carry the head low while walking (head at %.2f m)" % walking_head)

	for ignored in 90:
		marker.position.z += 1.8 * STEP
		animal.animate(STEP, "fleeing")
	_assert(animal.head.global_position.y > walking_head + 0.08, "fleeing should stretch the neck out ahead, head higher than when walking")

	for ignored in 180:
		animal.animate(STEP, "feeding")
	var muzzle: Vector3 = animal.head.global_transform * Vector3(0.0, -0.05, 0.27)
	_assert(absf(muzzle.y - marker.position.y) < 0.08, "feeding should bring the flat muzzle down to the ground (%.3f m)" % (muzzle.y - marker.position.y))

	animal.set_juvenile(true)
	_assert(animal.scale.x < 0.8, "a juvenile should be smaller")

	if failed:
		quit(1)
	else:
		print("PASS: the grazer walks on four legs without skating (worst slip %.4f m over %d steps, at least %d feet down), carries its head low, stretches its neck out to flee, mows at ground level to feed, and draws juveniles smaller" % [worst_slip, steps_taken, fewest_planted])
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL: ", message)
