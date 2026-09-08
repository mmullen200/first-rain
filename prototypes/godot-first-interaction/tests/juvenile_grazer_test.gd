extends SceneTree

const Grid = preload("res://ecology_grid.gd")
const Animals = preload("res://animal_simulation.gd")

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_family_behavior()
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.animal_simulation.register_agent("grazer", "grazer:2", {"cell": Vector2i(7, 8), "parents": ["grazer:1"]})
	scene._update_ecological_animal_markers()
	var marker: Node3D = scene.animal_markers["grazer:2"]
	var before := marker.position
	scene.animal_simulation._move_agent("grazer:2", Vector2i(8, 8))
	scene._update_ecological_animal_markers()
	var tick_jump := marker.position.distance_to(before)
	_assert(tick_jump < 0.001, "juvenile presentation jumped on a simulation tick: %.4f world units" % tick_jump)
	var moved_frames := 0
	var max_frame := 0.0
	for ignored in range(60):
		var previous := marker.position
		scene._physics_process(1.0 / 60.0)
		var distance := marker.position.distance_to(previous)
		max_frame = maxf(max_frame, distance)
		if distance > 0.00001:
			moved_frames += 1
	_assert(moved_frames > 20 and max_frame < 0.08, "juvenile needs continuous bounded travel; moving frames=%d max=%.4f" % [moved_frames, max_frame])
	scene.queue_free()
	if not failed:
		print("PASS: continuous juvenile motion, local parental following/forage, fear/reunion, bounded memory, maturation and replay")
	quit(1 if failed else 0)


func _family():
	var grid = Grid.new()
	grid.toxicity.fill(0.0)
	grid.moss.fill(0.0)
	grid.rhizome.fill(0.0)
	var simulation = Animals.new(grid, 17)
	simulation.register_agent("grazer", "adult", {"cell": Vector2i(8, 8)})
	simulation.register_agent("grazer", "child", {"cell": Vector2i(5, 8), "parents": ["adult"], "body_biomass": 0.4})
	return simulation


func _test_family_behavior() -> void:
	var simulation = _family()
	simulation.ecology.add_resources(Vector2i(5, 8), {"moss": 0.8})
	var choice: Dictionary = simulation._choose_intention(simulation.agent_state("child"))
	_assert(choice["type"] == "move" and choice.get("cell", Vector2i.ZERO).x > 5, "separated juvenile ate instead of catching up")
	simulation._resolve_intention(choice)
	_assert(simulation.agent_state("child")["parent_id"] == "adult", "juvenile lacks stable parent identity")
	# A distant relocation is deliberately invisible to the juvenile.
	simulation.agents["adult"]["cell"] = Vector2i(20, 8)
	simulation.agents["child"]["move_cooldown"] = 0
	choice = simulation._choose_intention(simulation.agent_state("child"))
	_assert(simulation.agent_state("child")["parent_last_seen"] == Vector2i(8, 8), "juvenile learned distant parent location")
	_assert(choice.get("cell", Vector2i.ZERO).x <= 8, "juvenile chased distant parent with global knowledge")
	simulation.agents["child"]["cell"] = Vector2i(8, 8)
	simulation.agents["child"]["parent_memory_ticks"] = 0
	for ignored in range(150):
		simulation._resolve_intention(simulation._choose_intention(simulation.agent_state("child")))
		_assert(simulation._cell_distance(simulation.agent_state("child")["cell"], Vector2i(8, 8)) <= 3, "lost juvenile search escaped last-known neighborhood")
	var local = _family()
	local.agents["child"]["cell"] = Vector2i(7, 8)
	local.ecology.add_resources(Vector2i(7, 8), {"moss": 0.3})
	local.ecology.add_resources(Vector2i(3, 8), {"moss": 1.0})
	choice = local._choose_intention(local.agent_state("child"))
	_assert(choice["type"] == "consume", "near-parent juvenile ignored nearby forage")
	local._resolve_intention(choice)
	# Immediate danger outranks reunion, then memory guides recovery.
	local.agents["child"]["fear"] = 0.9
	local.agents["child"]["threat_cell"] = Vector2i(8, 8)
	local.agents["child"]["move_cooldown"] = 0
	choice = local._choose_intention(local.agent_state("child"))
	_assert(choice["type"] == "move" and choice.get("cell", Vector2i.ZERO).x < 7, "juvenile followed parent toward immediate danger")
	local._resolve_intention(choice)
	local.agents["child"]["fear"] = 0.0
	local.agents["child"]["move_cooldown"] = 0
	choice = local._choose_intention(local.agent_state("child"))
	_assert(choice["type"] == "move" and choice.get("cell", Vector2i.ZERO).x > 6, "calm juvenile did not reunite")
	var saved: Dictionary = local.snapshot()
	for ignored in range(80):
		local.step()
	var replay = Animals.new(Grid.new(), 1)
	_assert(replay.restore(saved), "family snapshot failed to restore")
	for ignored in range(80):
		replay.step()
	_assert(replay.snapshot() == local.snapshot(), "family/memory state failed exact replay")
	var growing = _family()
	growing.agents["child"]["development_ticks"] = Animals.JUVENILE_MATURATION_TICKS - 1
	growing.agents["child"]["hunger"] = 0.0
	var biomass: float = growing.agent_state("child")["body_biomass"]
	growing._choose_intention(growing.agent_state("child"))
	_assert(not growing.agent_state("child")["juvenile"], "well-fed maturing grazer remained dependent")
	_assert(growing.agent_state("child")["body_biomass"] == biomass, "behavioral maturation manufactured biomass")
	var orphan = _family()
	orphan._choose_intention(orphan.agent_state("child"))
	orphan.agents["adult"]["alive"] = false
	orphan.agents["adult"]["cell"] = Vector2i(20, 8)
	orphan._choose_intention(orphan.agent_state("child"))
	_assert(orphan.agent_state("child")["parent_last_seen"] == Vector2i(8, 8), "dead parent continued refreshing memory")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL: " + message)
