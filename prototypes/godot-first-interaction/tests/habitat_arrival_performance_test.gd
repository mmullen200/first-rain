extends SceneTree

const SAMPLE_COUNT := 12
const FRAME_BUDGET_USEC := 8000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	for ignored in range(2):
		scene._seed_integrated_animals()
	var started := Time.get_ticks_usec()
	for ignored in range(SAMPLE_COUNT):
		scene._seed_integrated_animals()
	var average_usec := (Time.get_ticks_usec() - started) / SAMPLE_COUNT
	print("Habitat arrival scan average: %d usec" % average_usec)
	if average_usec > FRAME_BUDGET_USEC:
		push_error("FAIL: habitat arrival scanning exceeds one half-frame budget (%d > %d usec)" % [average_usec, FRAME_BUDGET_USEC])
		quit(1)
	else:
		print("PASS: habitat arrival scanning stays below one half-frame budget")
		quit(0)
