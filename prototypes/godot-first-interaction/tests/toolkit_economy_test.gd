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
	scene.reservoir_established = true
	scene.refuge_revealed = true
	scene.astronaut.position = scene.refuge_position
	scene._update_nearby_interactions()
	scene._interact()
	if scene.water_doses != 1:
		_fail("reservoir did not refill exactly one canister")
		return
	scene.water_doses = 0
	scene.reservoir_established = false
	scene.reclaimer_intact = true
	scene._dismantle_reclaimer()
	if scene.water_doses != 1 or scene.reclaimer_intact:
		_fail("reclaimer sacrifice did not exchange servicing for water")
		return
	print("PASS: toolkit supports free shade placement, persistent bulky drops, reservoir refill, and irreversible reclaimer sacrifice")
	quit(0)

func _fail(message: String) -> void:
	printerr("FAIL: " + message)
	quit(1)
