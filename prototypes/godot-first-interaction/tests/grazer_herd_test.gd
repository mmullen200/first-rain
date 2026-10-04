extends SceneTree

# Grazer herds (#51): the herd stays together, rests in step with one on
# watch, follows the green, panics together, breeds slowly and only in good
# times (a bull and a cow, through a visible pregnancy), and on screen walks curving paths instead of pivoting cell to cell.

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
	_check_sexes_and_pregnancy()
	_check_lost_pregnancy()
	_check_pregnancy_shows()
	await _check_smooth_walking()
	if failures.is_empty():
		print("PASS: grazers keep together, rest in step with a lookout, follow the green, bolt together, breed slowly as bulls and cows through a visible pregnancy, and walk curving paths")
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


func _pair(sexes: Array):
	var ecology = EcologyGrid.new()
	_meadow(ecology, Vector2i(6, 6), Vector2i(10, 8), 0.6)
	var simulation = AnimalSimulation.new(ecology, 7)
	for index in sexes.size():
		simulation.register_agent("grazer", "grazer:%d" % (index + 1), {"cell": Vector2i(9 + index, 9), "hunger": 0.0, "body_biomass": 0.9, "reproductive_readiness": 1.0, "sex": sexes[index]})
	return simulation


func _check_sexes_and_pregnancy() -> void:
	var same = _pair(["female", "female"])
	for ignored in 30:
		same.step()
	_expect(not _has(same.event_history, "organism.conceived"), "two females mated")
	var simulation = _pair(["female", "male"])
	simulation.step()
	_expect(_has(simulation.event_history, "organism.conceived"), "a ready female and male beside each other did not mate")
	_expect(int(simulation.agents["grazer:1"]["gestation_ticks"]) > 0 and String(simulation.agents["grazer:1"]["sire"]) == "grazer:2", "the female did not become pregnant by the male")
	_expect(is_equal_approx(float(simulation.agents["grazer:2"]["reproductive_readiness"]), AnimalSimulation.GRAZER_MALE_RECOVERY), "the male did not keep part of his condition")
	var born_at := -1
	var birth_weight := 0.0
	for tick in AnimalSimulation.GRAZER_GESTATION_TICKS + 40:
		for event in simulation.step():
			if event["taxonomy"] == "organism.reproduced" and born_at < 0:
				born_at = tick
				birth_weight = float(simulation.agents[event["subject"]]["body_biomass"])
			_expect(event["taxonomy"] != "organism.conceived", "a pregnant female mated again")
	_expect(born_at >= AnimalSimulation.GRAZER_GESTATION_TICKS - 5, "the calf came before the pregnancy ran its course (tick %d)" % born_at)
	var calf_ids: Array = simulation.agents.keys().filter(func(id): return String(id).begins_with("grazer:offspring:"))
	_expect(calf_ids.size() == 1, "one pregnancy did not give one calf")
	if calf_ids.size() == 1:
		var calf: Dictionary = simulation.agents[calf_ids[0]]
		_expect(calf["parent_id"] == "grazer:1" and calf["parents"] == ["grazer:1", "grazer:2"], "the calf does not follow its mother or know its sire")
		_expect(String(calf["sex"]) in ["female", "male"], "the calf has no sex")
		_expect(absf(birth_weight - AnimalSimulation.GRAZER_CALF_BODY) < 0.001, "the calf was born weighing %.3f, not what its mother carried" % birth_weight)
	_expect(int(simulation.agents["grazer:1"]["gestation_ticks"]) == 0 and float(simulation.agents["grazer:1"]["carried_young"]) == 0.0, "the mother was still carrying after the birth")
	_expect(simulation.conservation_violations.is_empty(), "pregnancy broke conservation: %s" % [simulation.conservation_violations])


func _check_lost_pregnancy() -> void:
	var simulation = _pair(["female", "male"])
	simulation.step()
	for ignored in 100:
		simulation.step()
	var carried := float(simulation.agents["grazer:1"]["carried_young"])
	_expect(carried > 0.0, "the mother was not building her calf")
	var detritus_before: float = simulation.ecology.resource_amount(simulation.agents["grazer:1"]["cell"], "dead_biomass")
	simulation.submit_intervention({"type": "injure", "agent_id": "grazer:1", "amount": 0.75})
	simulation.step()
	simulation.step()
	_expect(_has(simulation.event_history, "organism.pregnancy_lost"), "a badly wounded mother kept her pregnancy")
	_expect(int(simulation.agents["grazer:1"]["gestation_ticks"]) == 0, "the lost pregnancy did not end")
	var detritus_after: float = simulation.ecology.resource_amount(simulation.agents["grazer:1"]["cell"], "dead_biomass")
	_expect(detritus_after > detritus_before + carried * 0.5, "the lost calf's body did not go to the ground")
	_expect(simulation.conservation_violations.is_empty(), "a lost pregnancy broke conservation: %s" % [simulation.conservation_violations])


func _check_pregnancy_shows() -> void:
	var GrazerFigure = load("res://grazer_figure.gd")
	var cow = GrazerFigure.new()
	var bull = GrazerFigure.new()
	bull.set_male(true)
	var flat: Vector3 = cow.belly_mesh.scale
	cow.set_pregnancy(1.0)
	_expect(cow.belly_mesh.scale.x > flat.x * 1.4 and cow.belly_mesh.scale.y > flat.y * 1.6, "a full-term belly does not visibly swell")
	_expect(bull.spines[0].scale.y > cow.spines[0].scale.y * 2.5, "a bull's crest is not clearly taller than a cow's")
	cow.free()
	bull.free()


func _has(events: Array, taxonomy: String) -> bool:
	for event in events:
		if event["taxonomy"] == taxonomy:
			return true
	return false


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
