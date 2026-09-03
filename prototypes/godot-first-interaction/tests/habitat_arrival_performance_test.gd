extends SceneTree

const SAMPLE_COUNT := 12
const FRAME_BUDGET_USEC := 8000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	# Satisfy the first animal's ecological prerequisite so this benchmark times
	# the distributed habitat scan rather than the cheap precondition guard.
	scene.ecology.add_resources(Vector2i(4, 12), {"ground_bloom": 0.16})
	for y in range(12, 15):
		for x in range(20, 23):
			scene.ecology.add_resources(Vector2i(x, y), {"dead_biomass": 0.2})
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
