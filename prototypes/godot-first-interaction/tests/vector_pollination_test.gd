extends SceneTree

const Grid = preload("res://ecology_grid.gd")
const Animals = preload("res://animal_simulation.gd")
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var grid = Grid.new()
	var a := Vector2i(6, 8)
	var b := Vector2i(8, 8)
	for cell in [a, b, Vector2i(7, 9)]:
		var i: int = cell.y * grid.WIDTH + cell.x
		grid.moisture[i] = 0.65
		grid.temperature[i] = 0.35
		grid.toxicity[i] = 0.0
		grid.nutrients[i] = 0.5
		grid.add_resources(cell, {"rhizome": 0.5, "ground_bloom": 0.4})
	grid.add_resources(Vector2i(7, 9), {"canopy": 0.6, "canopy_bloom": 0.8})
	grid._step_reproduction()
	check(grid.receive_pollen(a, a, "rhizome", 0.04) == 0.0, "self-patch pollen was accepted")
	check(grid.receive_pollen(a, b, "canopy", 0.04) == 0.0, "incompatible pollen was accepted")
	var tissue: float = grid.resource_amount(a, "rhizome")
	check(grid.receive_pollen(a, b, "rhizome", 0.04) > 0.0, "compatible pollen rejected")
	check(is_equal_approx(tissue - grid.resource_amount(a, "rhizome"), 0.01), "seed tissue was not paid by parent")
	check(grid.developing_seeds[0]["age"] == 0, "pollination immediately established a seedling")
	var reward: float = grid.flower_reward(a)
	check(is_equal_approx(grid.take_nectar(a, 1.0), reward), "nectar consumption exceeded finite stock")
	check(grid.take_nectar(a, 1.0) == 0.0, "depleted flower provided food")
	for i in range(89):
		grid._step_reproduction()
	check(grid.developing_seeds[0]["age"] == 89, "seed maturation timing changed")
	# A mature seed cannot establish in an unsuitable neighborhood.
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var target: Vector2i = a + d
		grid.moisture[target.y * grid.WIDTH + target.x] = 0.0
	grid._step_reproduction()
	check(grid.developing_seeds.size() == 1, "seed established on dry ground")
	var target := a + Vector2i(1, 0)
	var idx: int = target.y * grid.WIDTH + target.x
	grid.moisture[idx] = 0.6
	grid.nutrients[idx] = 0.4
	grid.toxicity[idx] = 0.0
	grid.temperature[idx] = 0.35
	grid.rhizome[idx] = 0.0
	grid._step_reproduction()
	check(grid.developing_seeds.is_empty() and grid.rhizome[idx] > 0.0, "mature seeds failed suitable establishment")
	var sim = Animals.new(grid, 41)
	sim.register_agent("vector", "vector:1", {"cell": a})
	var remote := a + Vector2i(4, 0)
	grid.add_resources(remote, {"rhizome": 0.5, "ground_bloom": 0.5})
	grid.flower_stores[remote] = {"nectar": 0.035}
	sim._choose_vector_intention(sim.agents["vector:1"])
	check(not sim.agent_state("vector:1")["flower_memory"].has(remote), "unobserved flower inside home range leaked into memory")
	for i in range(240):
		sim.step()
	var visits := {}
	var pollinations := 0
	for event in sim.event_history:
		if event["taxonomy"] == "organism.nectar_consumed":
			visits[event["facts"]["cell"]] = true
		if event["taxonomy"] == "organism.patch_pollinated":
			pollinations += 1
			check(event["facts"]["donor"] != event["facts"]["cell"], "same-patch fertilization in live behavior")
	check(visits.size() >= 2, "vector did not leave and visit another rewarding flower")
	check(pollinations > 0, "live vector never cross-pollinated")
	var restored = Animals.new(Grid.new(), 1)
	check(restored.restore(sim.snapshot()), "snapshot restore failed")
	for i in range(40):
		sim.step()
		restored.step()
	check(sim.snapshot() == restored.snapshot(), "flower memory/seed development replay diverged")
	# A remembered remote reward expires without resensing it.
	sim.agents["vector:1"]["cell"] = a
	sim.agents["vector:1"]["flower_memory"][remote] = {"reward": 0.035, "seen": sim.tick - 181}
	sim._choose_vector_intention(sim.agents["vector:1"])
	check(not sim.agent_state("vector:1")["flower_memory"].has(remote), "stale flower memory did not expire")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene._seed_vector_fixture()
	var marker: Node3D = scene.animal_markers["vector:1"]
	var before := marker.position
	scene.animal_simulation.agents["vector:1"]["cell"] += Vector2i(1, 0)
	scene._update_ecological_animal_markers()
	check(marker.position == before, "vector marker jumped on ecology update")
	scene._update_vector_markers(1.0 / 60.0)
	check(marker.position.distance_to(before) > 0.0 and marker.position.distance_to(before) <= 0.034, "flight is not continuously speed-bounded")
	scene.field_review_open = true
	before = marker.position
	scene._physics_process(1.0)
	check(marker.position == before, "pause failed to stop flight")
	var fixture_seedlings := 0
	for i in range(240):
		for event in scene.animal_simulation.step():
			if event["taxonomy"] == "ecology.seedling_established":
				fixture_seedlings += 1
	check(not scene.ecology.developing_seeds.is_empty(), "living fixture produced no seed batches")
	# Rewet an open margin after seeds mature; no seed or plant is inserted.
	scene._open_emergency_cache()
	scene.astronaut.position = scene.patches["hollow"]["node"].position
	scene._update_nearby_interactions()
	var doses: int = scene.water_doses
	scene._request_water_intervention()
	check(scene.water_doses == doses - 1, "playable margin watering did not consume one carried dose")
	for event in scene.animal_simulation.step():
		if event["taxonomy"] == "ecology.seedling_established":
			fixture_seedlings += 1
	check(fixture_seedlings > 0, "fixture's mature seeds failed after a finite watering of the open margin")
	scene.queue_free()
	await process_frame
	if not failed:
		print("PASS: finite nectar, compatible crossings, delayed conditional seed establishment and exact replay")
	quit(1 if failed else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL: " + message)
