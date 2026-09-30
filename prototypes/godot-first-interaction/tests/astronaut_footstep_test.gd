extends SceneTree

const AstronautFigure = preload("res://astronaut_figure.gd")
const STEP := 1.0 / 60.0

var failed := false
var steps := 0


func _initialize() -> void:
	var figure = AstronautFigure.new()
	root.add_child(figure)
	figure.footstep.connect(func() -> void: steps += 1)

	for ignored in 180:
		figure.animate(STEP, 0.0)
	_assert(steps == 0, "standing still should make no footsteps (%d)" % steps)

	# Three seconds at full walking pace: two footfalls per stride cycle.
	for ignored in 30:
		figure.animate(STEP, AstronautFigure.REFERENCE_SPEED)
	steps = 0
	for ignored in 180:
		figure.animate(STEP, AstronautFigure.REFERENCE_SPEED)
	var expected := 2.0 * AstronautFigure.REFERENCE_SPEED * 3.0 * AstronautFigure.STRIDE_RADIANS_PER_METRE / TAU
	_assert(absf(float(steps) - expected) <= 1.0, "walking should land %.1f footsteps in three seconds, not %d" % [expected, steps])
	var walking_steps := steps

	# Stopping, the walk fades and the feet go quiet.
	steps = 0
	for ignored in 120:
		figure.animate(STEP, 0.0)
	_assert(steps == 0, "a stopped astronaut should make no footsteps (%d)" % steps)

	# Nudging against a wall barely moves the figure: no footfalls.
	for ignored in 180:
		figure.animate(STEP, 0.2)
	_assert(steps == 0, "a shuffle should not crunch (%d)" % steps)

	if failed:
		quit(1)
	else:
		print("PASS: the astronaut's feet land %d times in three seconds of walking, and not at all standing still, after stopping or while shuffling" % walking_steps)
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL: ", message)
