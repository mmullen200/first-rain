extends SceneTree

# Herd birds (#52): a flock rides with a grazer herd, feeds on the insects in
# its dung, and sees a hunting predator long before the herd does, even in
# cover, setting the whole herd running. A gorged predator is left alone. The
# lizard no longer lives on dung. Eggs at hoodoo feet hatch when a herd
# grazes nearby and die if it leaves while they stir.

const EcologyGrid = preload("res://ecology_grid.gd")
const AnimalSimulation = preload("res://animal_simulation.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_alarm_through_cover()
	_check_lookout_needs_open_ground()
	_check_gorged_predator_ignored()
	_check_flock_follows_and_feeds()
	_check_lizard_skips_dung()
	await _check_clutches()
	await _check_flock_on_screen()
	if failures.is_empty():
		print("PASS: herd birds ride and feed with the herd, warn it of a hunting predator through cover, hatch beside a grazing herd, and the lizard hunts instead of eating dung")
		quit(0)
		return
	for failure in failures:
		printerr("FAIL: ", failure)
	quit(1)


func _meadow(ecology, corner: Vector2i, size: Vector2i, forage: float, cover := 0.0) -> void:
	for y in range(corner.y, corner.y + size.y):
		for x in range(corner.x, corner.x + size.x):
			var index: int = y * ecology.WIDTH + x
			ecology.moisture[index] = 0.6
			ecology.toxicity[index] = 0.02
			ecology.temperature[index] = 0.38
			ecology.nutrients[index] = 0.5
			ecology.add_resources(Vector2i(x, y), {"moss": forage * 0.6, "rhizome": forage * 0.4, "canopy": cover})


func _scene(with_birds: bool, predator_cell: Vector2i, cover: float, hunger := 1.0):
	var ecology = EcologyGrid.new()
	_meadow(ecology, Vector2i(4, 4), Vector2i(20, 14), 0.6, cover)
	var simulation = AnimalSimulation.new(ecology, 7)
	for index in 4:
		simulation.register_agent("grazer", "grazer:%d" % (index + 1), {"cell": Vector2i(10 + index % 2, 10 + index / 2), "hunger": 0.5, "body_biomass": 0.9})
	if with_birds:
		simulation.register_agent("herd_bird", "herd_bird:1", {"cell": Vector2i(10, 10)})
	simulation.register_agent("predator", "predator:1", {"cell": predator_cell, "habitat_cell": predator_cell, "hunger": hunger})
	return simulation


func _frightened(simulation) -> int:
	var count := 0
	for id in simulation.agents:
		if simulation.agents[id]["species"] == "grazer" and float(simulation.agents[id]["fear"]) > 0.25:
			count += 1
	return count


func _check_alarm_through_cover() -> void:
	# A hungry lizard four cells off, creeping through shrubs.
	var warned = _scene(true, Vector2i(14, 10), 0.5)
	warned.step()
	warned.step()
	_expect(_has(warned.event_history, "organism.alarm_called"), "the flock did not raise the alarm at a hunting lizard four cells away in cover")
	_expect(_frightened(warned) == 4, "the alarm did not set the whole herd running (%d of 4 frightened)" % _frightened(warned))
	var unwarned = _scene(false, Vector2i(14, 10), 0.5)
	unwarned.agents["predator:1"]["move_cooldown"] = 99
	for ignored in 3:
		unwarned.step()
	_expect(_frightened(unwarned) == 0, "without birds the herd sensed a lizard four cells off in cover")


func _check_lookout_needs_open_ground() -> void:
	var open = _scene(false, Vector2i(12, 10), 0.0)
	open.agents["predator:1"]["move_cooldown"] = 99
	open.step()
	open.step()
	_expect(_has(open.event_history, "organism.lookout_spotted"), "the lookout missed a lizard two cells off in the open")
	var hidden = _scene(false, Vector2i(12, 10), 0.6)
	hidden.agents["predator:1"]["move_cooldown"] = 99
	hidden.step()
	hidden.step()
	_expect(not _has(hidden.event_history, "organism.lookout_spotted"), "the lookout saw a lizard hidden in shrubs")


func _check_gorged_predator_ignored() -> void:
	var simulation = _scene(true, Vector2i(14, 10), 0.0, 0.1)
	for ignored in 10:
		simulation.step()
	_expect(not _has(simulation.event_history, "organism.alarm_called"), "the flock raised the alarm at a gorged lizard")


func _check_flock_follows_and_feeds() -> void:
	var ecology = EcologyGrid.new()
	_meadow(ecology, Vector2i(4, 4), Vector2i(24, 14), 0.6)
	var simulation = AnimalSimulation.new(ecology, 7)
	for index in 4:
		simulation.register_agent("grazer", "grazer:%d" % (index + 1), {"cell": Vector2i(18 + index % 2, 10 + index / 2), "hunger": 0.5, "body_biomass": 0.9})
	simulation.register_agent("herd_bird", "herd_bird:1", {"cell": Vector2i(10, 10), "hunger": 0.9})
	var fed := false
	for ignored in 400:
		simulation.step()
		for event in simulation.event_history.slice(-6):
			fed = fed or (event["subject"] == "herd_bird:1" and event["taxonomy"] == "organism.dead_biomass_consumed")
	var flock: Dictionary = simulation.agents["herd_bird:1"]
	var centre: Vector2 = simulation.agents["grazer:1"]["herd_centre"]
	_expect(flock["host_herd"] == "grazer:1" or flock["host_herd"] == simulation.agents["grazer:1"]["herd_leader"], "the flock did not attach to the herd")
	_expect(Vector2(flock["cell"]).distance_to(centre) <= 2.0, "the flock was not with the herd (flock %s, herd %s)" % [flock["cell"], centre])
	_expect(fed, "the flock never fed on the herd's dung")
	_expect(simulation.conservation_violations.is_empty(), "the flock broke conservation: %s" % [simulation.conservation_violations])


func _check_lizard_skips_dung() -> void:
	var ecology = EcologyGrid.new()
	_meadow(ecology, Vector2i(4, 4), Vector2i(16, 12), 0.0)
	var simulation = AnimalSimulation.new(ecology, 7)
	simulation.register_agent("predator", "predator:1", {"cell": Vector2i(10, 10), "habitat_cell": Vector2i(10, 10), "hunger": 1.0})
	ecology.add_resources(Vector2i(11, 10), {"dead_biomass": 0.1})
	_expect(simulation._predator_detritus_cell(simulation.agents["predator:1"]) == Vector2i(-1, -1), "the lizard went for a dung-sized pile")
	ecology.add_resources(Vector2i(9, 11), {"dead_biomass": 0.6})
	_expect(simulation._predator_detritus_cell(simulation.agents["predator:1"]) == Vector2i(9, 11), "the lizard ignored carcass-sized remains")


func _check_clutches() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var clutches: Array[int] = []
	for index in scene.sleeper_field.sleepers.size():
		if scene.sleeper_field.sleepers[index]["species"] == "herd_bird":
			clutches.append(index)
	_expect(clutches.size() == scene.sleeper_field.HERD_BIRD_CLUTCHES, "expected %d clutches, found %d" % [scene.sleeper_field.HERD_BIRD_CLUTCHES, clutches.size()])
	for index in clutches:
		var cell: Vector2i = scene.sleeper_field.sleepers[index]["cell"]
		var beside_hoodoo := false
		for hoodoo in scene.hoodoo_field.hoodoo_cells:
			beside_hoodoo = beside_hoodoo or scene._cell_distance(cell, hoodoo) == 1
		_expect(beside_hoodoo, "a clutch at %s is not at a hoodoo's foot" % cell)
	if clutches.is_empty():
		scene.queue_free()
		return
	var clutch: int = clutches[0]
	var cell: Vector2i = scene.sleeper_field.sleepers[clutch]["cell"]
	for index in 2:
		scene.animal_simulation.register_agent("grazer", "grazer:%d" % (index + 3), {"cell": cell + Vector2i(1, index), "hunger": 0.5})
	var surveys: int = scene._calls_per_habitat_observation()
	for ignored in surveys * 2:
		scene._update_bird_clutches()
	_expect(scene.sleeper_states[clutch]["state"] == "stirring", "eggs did not stir beside a grazing herd")
	for ignored in surveys * 2:
		scene._update_bird_clutches()
	_expect(scene.sleeper_states[clutch]["state"] == "awake" and scene.animal_simulation.agents.has(scene.sleeper_states[clutch]["agent_id"]), "eggs did not hatch into a flock beside a grazing herd")
	# A second clutch stirs, then loses its herd.
	if clutches.size() > 1:
		var other: int = clutches[1]
		var other_cell: Vector2i = scene.sleeper_field.sleepers[other]["cell"]
		for index in 2:
			scene.animal_simulation.agents["grazer:%d" % (index + 3)]["cell"] = other_cell + Vector2i(1, index)
		for ignored in surveys * 2:
			scene._update_bird_clutches()
		for index in 2:
			scene.animal_simulation.agents["grazer:%d" % (index + 3)]["cell"] = Vector2i(1, 1)
		# While life persists they settle back to sleep; otherwise they die.
		var persists: bool = scene.life_persists
		for ignored in surveys:
			scene._update_bird_clutches()
		var expected := "dormant" if persists else "dead"
		_expect(scene.sleeper_states[other]["state"] == expected, "stirring eggs whose herd left became %s, not %s" % [scene.sleeper_states[other]["state"], expected])
	scene.queue_free()


func _check_flock_on_screen() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene._seed_herd_birds_fixture()
	var step := 1.0 / 30.0
	for ignored in 90:
		scene._update_grazer(step)
		scene._update_grazer_markers(step)
		scene._update_herd_birds(step)
	var flock = scene.animal_markers["herd_bird:1"].get_child(0)
	var riding := 0
	for bird in flock.birds:
		var node: Node3D = bird["node"]
		for grazer_id in ["grazer:1", "grazer:2", "grazer:3", "grazer:4", "grazer:5", "grazer:6"]:
			var body: Node3D = scene.grazer_root if grazer_id == "grazer:1" else scene.animal_markers[grazer_id]
			if Vector2(node.global_position.x, node.global_position.z).distance_to(Vector2(body.global_position.x, body.global_position.z)) < 1.0:
				riding += 1
				break
	_expect(riding >= 4, "only %d of 5 birds were with the grazers" % riding)
	scene.animal_simulation.agents["herd_bird:1"]["state"] = "alarm"
	scene.animal_simulation.agents["herd_bird:1"]["alarm_ticks"] = 99
	for ignored in 60:
		scene._update_herd_birds(step)
	var ground: float = scene.grazer_root.global_position.y
	_expect(flock.alarmed_birds_above(ground + 2.0) == 5, "the flock did not burst up over the herd on the alarm")
	scene.queue_free()


func _has(events: Array, taxonomy: String) -> bool:
	for event in events:
		if event["taxonomy"] == taxonomy:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
