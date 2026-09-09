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
	scene.astronaut.position = scene.shade_panel.position
	scene._update_nearby_interactions()
	scene._interact()
	if not scene.carrying_shade:
		_fail("shade panel was not physically retrieved")
		return
	scene.astronaut.position = Vector3(1.2, 0.0, 0.8)
	scene._interact_with_shade()
	if not scene.shade_placed:
		_fail("shade panel did not place on the chosen ecological cell")
		return
	var cell: Vector2i = scene.shade_placed_cell
	var shaded: float = scene.ecology.cell_snapshot(cell.x, cell.y)["shade"]
	scene.astronaut.position = scene.shade_panel.position
	scene._interact_with_shade()
	if not scene.carrying_shade or scene.ecology.cell_snapshot(cell.x, cell.y)["shade"] >= shaded:
		_fail("retrieval did not remove the old shade footprint")
		return
	scene.astronaut.position = Vector3(2.0, 0.0, -0.5)
	scene._recover_at_wreck(true)
	if scene.carrying_shade or not scene.shade_placed:
		_fail("forced recovery did not leave the bulky panel in the field")
		return
	scene.water_doses = 0
	scene.ship_water_production_elapsed = 0.0
	scene.cache_opened = false
	scene._update_ship_water_production(scene.SHIP_WATER_PRODUCTION_SECONDS)
	if scene.water_doses != 0:
		_fail("wreck produced water before the emergency cache was opened")
		return
	scene.cache_opened = true
	scene.field_review_open = true
	scene._physics_process(scene.SHIP_WATER_PRODUCTION_SECONDS)
	if scene.water_doses != 0 or scene.ship_water_production_elapsed != 0.0:
		_fail("wreck produced water while the Basin Survey paused the simulation")
		return
	scene.field_review_open = false
	scene._update_ship_water_production(scene.SHIP_WATER_PRODUCTION_SECONDS - 0.1)
	if scene.water_doses != 0:
		_fail("wreck produced water before a full production interval")
		return
	scene._update_ship_water_production(0.1)
	if scene.water_doses != 1:
		_fail("wreck did not produce exactly one water dose per interval")
		return
	scene._update_ship_water_production(scene.SHIP_WATER_PRODUCTION_SECONDS * 20.0)
	if scene.water_doses != scene.MAX_WATER_DOSES:
		_fail("wreck water production did not stop at its ten-dose capacity")
		return
	scene.water_doses = 0
	scene.refuge_watered = true
	scene.refuge_revealed = true
	scene.astronaut.position = scene.refuge_position
	scene._update_nearby_interactions()
	scene._interact()
	if scene.water_doses != 0:
		_fail("the one-dose depression created renewable water")
		return
	print("PASS: toolkit supports free shade placement, persistent bulky drops, capped wreck water production, and a finite depression pool")
	quit(0)

func _fail(message: String) -> void:
	printerr("FAIL: " + message)
	quit(1)
