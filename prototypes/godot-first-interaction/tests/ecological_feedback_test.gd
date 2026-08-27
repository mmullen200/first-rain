extends SceneTree


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
	scene._scan_nearby_patch()
	if not scene.scanner_readout.text.contains("baseline stored"):
		_fail("the first sheltered scan did not store a baseline", scene.scanner_readout.text)
		return
	if not scene.scan_pulse.visible or scene.scan_pulse_timer <= 0.0:
		_fail("the sheltered scan did not produce a world-space pulse")
		return

	scene._toggle_analysis_lens()
	if not scene.analysis_lens_enabled:
		_fail("the local analysis lens did not activate")
		return

	scene.astronaut.position = scene.patches["crust"]["node"].position
	scene._update_nearby_interactions()
	scene._scan_nearby_patch()
	var exposed_readout: String = scene.scanner_readout.text
	if not exposed_readout.contains("COMPARE    HOLLOW:"):
		_fail("the exposed scan did not compare itself with the sheltered baseline", exposed_readout)
		return
	if not exposed_readout.contains("hotter") or not exposed_readout.contains("more toxic"):
		_fail("the exposed scan did not report its relevant environmental differences", exposed_readout)
		return

	scene.astronaut.position = scene.patches["hollow"]["node"].position
	scene._update_nearby_interactions()
	scene._water_nearby_patch()
	scene._scan_nearby_patch()
	if not scene.scanner_readout.text.contains("CHANGE     moisture rose"):
		_fail("the sheltered rescan did not report the intervention's moisture change", scene.scanner_readout.text)
		return

	print("PASS: scanner baselines, comparisons, rescans, pulse, and local lens expose bounded ecological feedback")
	quit(0)


func _fail(message: String, detail := "") -> void:
	printerr("FAIL: ", message)
	if not detail.is_empty():
		printerr(detail)
	quit(1)
