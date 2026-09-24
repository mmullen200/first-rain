extends SceneTree

const EcologyGridModel = preload("res://ecology_grid.gd")
const HoodooField = preload("res://hoodoo_field.gd")
const AnimalSimulation = preload("res://animal_simulation.gd")

var failed := false
var queen_report := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_workers_eat_the_queens_hoodoo()
	_check_old_matter_never_rots()
	await _check_colony_opens_the_spring()
	if failed:
		quit(1)
	else:
		print("PASS: workers break down hoodoos into the fungus garden, old matter never rots on its own, spires shrink to what is left, and eating the spring spire opens the spring")
		quit(0)


# Beside a queen's hoodoo with no plants in reach, workers carry the hoodoo
# itself home, and every crumb taken arrives as Detritus at the nest.
func _check_workers_eat_the_queens_hoodoo() -> void:
	var ecology = EcologyGridModel.new()
	var field = HoodooField.new()
	field.build(ecology)
	var queen: Vector2i = field.queen_cells[0]
	var home := queen + Vector2i(1, 0)
	var simulation = AnimalSimulation.new(ecology, 7)
	simulation.register_agent("colony", "colony:1", {"cell": home})
	var start: float = ecology.resource_amount(queen, "old_matter")
	_assert(start > 0.2, "a hoodoo should hold old matter in proportion to its height")
	var gathered := 0.0
	var returned := 0.0
	var rust_carried := false
	for ignored in range(900):
		for event in simulation.step():
			if event["taxonomy"] == "organism.colony_hoodoo_gathered" and event["facts"]["cell"] == queen:
				gathered += float(event["facts"]["amount"])
			if event["taxonomy"] == "organism.colony_plant_returned" and event["facts"]["source_resource"] == "old_matter":
				returned += float(event["facts"]["amount"])
		for worker in simulation.agents["colony:1"]["workers"]:
			rust_carried = rust_carried or (worker["resource"] == "old_matter" and float(worker["load"]) > 0.0)
	var left: float = ecology.resource_amount(queen, "old_matter")
	queen_report = "%.2f of %.2f left after %.0f s" % [left, start, 900 * 0.34]
	_assert(left < start * 0.8, "workers should visibly wear down the hoodoo beside their nest (%.3f of %.3f left)" % [left, start])
	_assert(rust_carried, "workers should be seen carrying hoodoo pieces")
	_assert(absf(gathered - (start - left)) < 0.0005, "everything taken from the hoodoo should be accounted for by workers (%.4f taken, %.4f gathered)" % [start - left, gathered])
	_assert(returned > 0.0, "hoodoo pieces should reach the nest as Detritus")
	_assert(simulation.conservation_violations.is_empty(), "hoodoo transport should conserve material: %s" % [simulation.conservation_violations])
	field.sync(ecology)
	var body: Node3D = field.get_node("Hoodoo_%d_%d" % [queen.x, queen.y])
	_assert(body.get_node("Mass").scale.y < 1.0, "a partly eaten hoodoo should stand lower")
	field.free()


func _check_old_matter_never_rots() -> void:
	var ecology = EcologyGridModel.new()
	var spring := EcologyGridModel.HEADWALL_SPRING_CELL
	_assert(is_equal_approx(ecology.resource_amount(spring, "old_matter"), EcologyGridModel.SPRING_SEAL_MATTER), "the spring should start sealed by old matter")
	ecology.add_water(ecology.world_position(spring.x, spring.y), 0.9, 6.0)
	for ignored in range(600):
		ecology.step()
	_assert(is_equal_approx(ecology.resource_amount(spring, "old_matter"), EcologyGridModel.SPRING_SEAL_MATTER), "weather and water alone should never wear the seal")
	_assert(not ecology.spring_open, "the spring should stay shut while its seal stands")
	var snapshot: Dictionary = ecology.full_snapshot()
	var copy = EcologyGridModel.new()
	_assert(copy.restore_snapshot(snapshot), "snapshots should carry old matter and the spring")


# The fixture puts a colony within reach of the spring spire; left alone, the
# workers eat it away and the spring runs down its old watercourse.
func _check_colony_opens_the_spring() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene._seed_hoodoo_devouring_fixture()
	var spring := EcologyGridModel.HEADWALL_SPRING_CELL
	var spire: Node3D = scene.hoodoo_field.get_node("Hoodoo_%d_%d" % [spring.x, spring.y])
	var downstream: Vector2i = scene.ecology.flow_path(spring)[2]
	var dry_downstream: float = scene.ecology.resource_amount(downstream, "surface_water")
	var halfway_step := -1
	var opened_step := -1
	var plants_cut := false
	for step in range(1400):
		scene._update_ecology_grid(scene.ECOLOGY_STEP_SECONDS)
		for event in scene.animal_simulation.event_history.slice(-40):
			plants_cut = plants_cut or event["taxonomy"] == "organism.colony_plant_gathered"
		if halfway_step < 0 and scene.ecology.resource_amount(spring, "old_matter") < EcologyGridModel.SPRING_SEAL_MATTER * 0.5:
			halfway_step = step
			_assert(not spire.get_node("Mass/Cap").visible, "a half-eaten spire should have lost its cap")
		if scene.ecology.spring_open:
			opened_step = step
			break
	var colony: Dictionary = scene.animal_simulation.agent_state("colony:1")
	_assert(bool(colony.get("present", false)), "the fixture colony should stay resident while it works")
	_assert(plants_cut, "workers should keep cutting plants while the spire is there")
	_assert(opened_step > 0, "a colony within reach should eventually eat the spring spire away")
	print("queen's hoodoo: %s; spire half gone after %.0f s, spring open after %.0f s" % [queen_report, halfway_step * scene.ECOLOGY_STEP_SECONDS, opened_step * scene.ECOLOGY_STEP_SECONDS])
	if opened_step > 0:
		_assert(not spire.get_node("Mass").visible, "no spire should remain over an open spring")
		_assert(spire.get_node("Collision").disabled, "the astronaut should be able to walk where the spire stood")
		_assert(scene.spring_label.text.ends_with("SPRING RUNNING"), "the Headwall label should report the spring running")
		for ignored in range(30):
			scene._update_ecology_grid(scene.ECOLOGY_STEP_SECONDS)
		_assert(scene.ecology.resource_amount(downstream, "surface_water") > dry_downstream + 0.02, "spring water should run down the old watercourse")
	scene.queue_free()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
		print("FAIL: ", message)
