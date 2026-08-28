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
	scene._water_nearby_patch()

	var hollow_world := Vector2(scene.patches["hollow"]["node"].position.x, scene.patches["hollow"]["node"].position.z)
	var hollow_cell: Vector2i = scene.ecology.world_to_cell(hollow_world)
	var hollow_index: int = scene.ecology._index(hollow_cell.x, hollow_cell.y)
	scene.patches["hollow"]["state"] = "thriving"
	scene.ecology.fungus[hollow_index] = 0.08
	scene.ecology.nutrients[hollow_index] = 0.15

	var water_before_moist_retry: int = scene.water_doses
	scene._update_nearby_interactions()
	if scene.prompt_label.text.contains("rewater"):
		printerr("FAIL: a still-moist established patch is presented as needing recovery water")
		quit(1)
		return
	scene._water_nearby_patch()
	if scene.water_doses != water_before_moist_retry:
		printerr("FAIL: a still-moist established patch consumed another water dose")
		quit(1)
		return

	scene.ecology.fruiting[hollow_index] = 0.06
	scene.ecology.apply_dust_front(hollow_cell.x)
	scene.ecology.moisture[hollow_index] = 0.0
	var fruiting_after_storm: float = scene.ecology.fruiting[hollow_index]
	var water_before_dry_retry: int = scene.water_doses
	scene._update_nearby_interactions()
	if not scene.prompt_label.text.contains("rewater dry habitat"):
		printerr("FAIL: the storm-dried habitat does not present a situated rewatering prompt; prompt=", scene.prompt_label.text)
		quit(1)
		return
	scene._water_nearby_patch()
	var moisture_after: float = scene.ecology.moisture[hollow_index]
	if scene.water_doses != water_before_dry_retry - 1 or moisture_after <= 0.0:
		printerr("FAIL: a storm-dried thriving patch rejects another water intervention; water-before=", water_before_dry_retry, " water-after=", scene.water_doses, " moisture-after=", moisture_after, " fruiting-after-storm=", fruiting_after_storm, " status=", scene.status_label.text)
		quit(1)
		return
	if scene.ecology.fruiting[hollow_index] >= 0.055:
		printerr("FAIL: recovery water restored harvestable fruiting tissue immediately instead of supporting regrowth")
		quit(1)
		return
	for ignored in range(30):
		scene.ecology.step()
	if scene.ecology.fruiting[hollow_index] < 0.055:
		printerr("FAIL: surviving fungus did not regrow harvestable fruiting tissue after the dry habitat was rewatered; fruiting=", scene.ecology.fruiting[hollow_index])
		quit(1)
		return

	print("PASS: moist habitat rejects redundant water while storm-dried established habitat accepts recovery water and regrows fruiting tissue")
	quit(0)
