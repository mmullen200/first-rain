extends SceneTree

# Grazer herds (#51): the herd stays together, rests in step with one on
# watch, follows the green, panics together, breeds slowly and only in good
# times, and on screen walks curving paths instead of pivoting cell to cell.

const EcologyGrid = preload("res://ecology_grid.gd")
const AnimalSimulation = preload("res://animal_simulation.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_cohesion_rest_and_lookout()
	_check_follows_the_green()
	_check_shared_fright()
	_check_slow_breeding()
	_check_no_breeding_in_hard_times()
	await _check_smooth_walking()
	if failures.is_empty():
		print("PASS: grazers keep together, rest in step with a lookout, follow the green, bolt together, breed slowly, and walk curving paths")
		quit(0)
		return
	for failure in failures:
		printerr("FAIL: ", failure)
	quit(1)


func _meadow(ecology, corner: Vector2i, size: Vector2i, forage: float) -> void:
	for y in range(corner.y, corner.y + size.y):
		for x in range(corner.x, corner.x + size.x):
			var index: int = y * ecology.WIDTH + x
			ecology.moisture[index] = 0.6
			ecology.toxicity[index] = 0.02
			ecology.temperature[index] = 0.38
			ecology.nutrients[index] = 0.5
			if forage > 0.0:
				ecology.add_resources(Vector2i(x, y), {"moss": forage * 0.6, "rhizome": forage * 0.4})


func _keep_damp(ecology, corner: Vector2i, size: Vector2i) -> void:
	for y in range(corner.y, corner.y + size.y):
		for x in range(corner.x, corner.x + size.x):
			var index: int = y * ecology.WIDTH + x
			ecology.moisture[index] = maxf(ecology.moisture[index], 0.5)


func _herd(ecology, count: int, at: Vector2i, readiness := 0.0):
	var simulation = AnimalSimulation.new(ecology, 7)
	for index in count:
		simulation.register_agent("grazer", "grazer:%d" % (index + 1), {"cell": at + Vector2i(index % 3, index / 3), "hunger": 0.5, "body_biomass": 0.9, "reproductive_readiness": readiness})
	return simulation


func _check_cohesion_rest_and_lookout() -> void:
	var ecology = EcologyGrid.new()
	_meadow(ecology, Vector2i(6, 6), Vector2i(16, 12), 0.6)
	var simulation = _herd(ecology, 6, Vector2i(10, 10))
	var together_ticks := 0
	var widest := 0.0
	var rest_ticks := 0
	var rest_in_step := 0
	var graze_ticks := 0
	var one_lookout := 0
	for ignored in 1200:
		_keep_damp(ecology, Vector2i(6, 6), Vector2i(16, 12))
		simulation.step()
		var first: Dictionary = simulation.agents["grazer:1"]
		if int(first["herd_size"]) == 6:
			together_ticks += 1
		var centre: Vector2 = first["herd_centre"]
		var watching := 0
		var resting := 0
		for id in simulation.agents:
			var agent: Dictionary = simulation.agents[id]
			widest = maxf(widest, Vector2(agent["cell"]).distance_to(centre))
			watching += 1 if agent["state"] == "watching" else 0
			resting += 1 if agent["state"] == "resting" else 0
		if first["herd_mode"] == "resting" and int(first["herd_mode_ticks"]) > 30:
			rest_ticks += 1
			if resting == 5 and watching == 1:
				rest_in_step += 1
		elif first["herd_mode"] == "grazing":
			graze_ticks += 1
			if watching == 1:
				one_lookout += 1
	_expect(together_ticks == 1200, "the herd split up (together %d of 1200 ticks)" % together_ticks)
	_expect(widest <= 4.5, "a grazer strayed %.1f cells from the herd centre" % widest)
	_expect(rest_ticks > 60, "the herd never settled to rest together")
	_expect(rest_in_step >= rest_ticks * 0.9, "resting was not in step: %d of %d settled rest ticks had five lying and one on watch" % [rest_in_step, rest_ticks])
	_expect(one_lookout >= graze_ticks * 0.8, "no steady lookout while grazing (%d of %d ticks)" % [one_lookout, graze_ticks])
	_expect(simulation.conservation_violations.is_empty(), "herd feeding broke conservation: %s" % [simulation.conservation_violations])


func _check_follows_the_green() -> void:
	var ecology = EcologyGrid.new()
	# Bare, grazed-out ground here; a green meadow seven cells east.
	_meadow(ecology, Vector2i(6, 8), Vector2i(6, 5), 0.0)
	_meadow(ecology, Vector2i(15, 8), Vector2i(5, 5), 0.7)
	var simulation = _herd(ecology, 5, Vector2i(7, 9))
	var set_off := -1
	for tick in 400:
		_keep_damp(ecology, Vector2i(15, 8), Vector2i(5, 5))
		var events: Array = simulation.step()
		for event in events:
			if event["taxonomy"] == "organism.herd_mode_changed" and event["facts"]["mode"] == "travelling" and set_off < 0:
				set_off = tick
	_expect(set_off >= 0 and set_off < 40, "the herd did not set off for the green meadow (set off at tick %d)" % set_off)
	for id in simulation.agents:
		var cell: Vector2i = simulation.agents[id]["cell"]
		_expect(cell.x >= 13 and cell.x <= 21 and cell.y >= 6 and cell.y <= 14, "%s did not arrive at the green meadow with the herd (at %s)" % [id, cell])


func _check_shared_fright() -> void:
	var ecology = EcologyGrid.new()
	_meadow(ecology, Vector2i(10, 8), Vector2i(12, 10), 0.6)
	var simulation = _herd(ecology, 5, Vector2i(14, 11))
	for ignored in 20:
		simulation.step()
	var before := {}
	for id in simulation.agents:
		before[id] = simulation.agents[id]["cell"]
	var threat := Vector2i(11, 11)
	simulation.agents["grazer:1"]["threat_cell"] = threat
	simulation.submit_intervention({"type": "deter", "agent_id": "grazer:1", "pressure": 0.9})
	simulation.step()
	for id in simulation.agents:
		_expect(float(simulation.agents[id]["fear"]) > 0.25, "%s did not take fright when its herd-mate did" % id)
	for ignored in 12:
		simulation.step()
	for id in simulation.agents:
		var moved := Vector2(simulation.agents[id]["cell"] - before[id])
		var away := Vector2(before[id] - threat)
		_expect(moved.length() >= 1.0 and moved.dot(away) > 0.0, "%s did not bolt away from the danger with the herd (moved %s)" % [id, moved])


func _check_slow_breeding() -> void:
	var ecology = EcologyGrid.new()
	_meadow(ecology, Vector2i(6, 6), Vector2i(16, 12), 0.6)
	var simulation = _herd(ecology, 4, Vector2i(10, 10))
	var first_birth := -1
	var births := 0
	for tick in 2400:
		_keep_damp(ecology, Vector2i(6, 6), Vector2i(16, 12))
		for event in simulation.step():
			if event["taxonomy"] == "organism.reproduced":
				births += 1
				if first_birth < 0:
					first_birth = tick
	_expect(first_birth >= 900, "the herd bred too soon (first birth at tick %d, under five minutes)" % first_birth)
	_expect(births >= 1 and births <= 2, "expected one or two births in about 14 minutes of good grazing, got %d" % births)
	for id in simulation.agents:
		if String(id).begins_with("grazer:offspring:"):
			_expect(int(simulation.agents[id]["herd_size"]) == simulation.agents.size(), "%s was not part of the herd" % id)
	_expect(simulation.conservation_violations.is_empty(), "breeding broke conservation: %s" % [simulation.conservation_violations])


func _check_no_breeding_in_hard_times() -> void:
	var ecology = EcologyGrid.new()
	# Dry, bare ground: nothing to spare and nothing regrowing.
	_meadow(ecology, Vector2i(6, 6), Vector2i(16, 12), 0.0)
	for index in ecology.moisture.size():
		ecology.moisture[index] = 0.0
	var simulation = _herd(ecology, 4, Vector2i(10, 10), 0.9)
	var births := 0
	for ignored in 1500:
		for event in simulation.step():
			births += 1 if event["taxonomy"] == "organism.reproduced" else 0
	_expect(births == 0, "the herd bred with no forage to spare (%d births)" % births)


func _check_smooth_walking() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene._seed_grazer_herd_fixture()
	var actor: Node3D = scene.grazer_root
	var previous_facing := actor.rotation.y
	var previous := Vector2(actor.position.x, actor.position.z)
	var previous_speed := 0.0
	var sharpest_turn := 0.0
	var biggest_jolt := 0.0
	var travelled := 0.0
	var step := 1.0 / 30.0
	for ignored in 1800:
		scene._update_ecology_grid(step)
		scene._update_grazer(step)
		scene._update_grazer_markers(step)
		var here := Vector2(actor.position.x, actor.position.z)
		var speed := here.distance_to(previous) / step
		sharpest_turn = maxf(sharpest_turn, absf(wrapf(actor.rotation.y - previous_facing, -PI, PI)) / step)
		biggest_jolt = maxf(biggest_jolt, absf(speed - previous_speed) / step)
		travelled += here.distance_to(previous)
		previous = here
		previous_speed = speed
		previous_facing = actor.rotation.y
	# Separation can nudge a body sideways, so allow some slack over the gait.
	_expect(sharpest_turn <= 3.3, "a grazer pivoted at %.1f rad/s instead of turning gradually" % sharpest_turn)
	_expect(travelled >= 2.0, "the lead grazer barely moved in a minute (%.1f m)" % travelled)
	_expect(biggest_jolt <= 40.0, "a grazer jerked between speeds (%.1f m/s²)" % biggest_jolt)
	scene.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
