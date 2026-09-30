extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _assert_sleepers_lie_in_fitting_ground()
	await _assert_habitat_away_from_sleepers_wakes_nothing()
	await _assert_vector_stirs_wakes_sleeps_and_wakes_again()
	await _assert_engineer_woken_too_early_dies()
	await _assert_grazer_needs_soaked_ground()
	await _assert_grazer_wakes_under_shrubs_beside_water()
	await _assert_grazers_never_overlap()
	await _assert_predator_rides_the_dust()
	if failed:
		quit(1)
	else:
		print("PASS: every animal wakes from a sleeper on the map, rises where it slept, dies if woken too early, sleeps again where it lies, and the predator comes down with a dust front")
		quit(0)


func _assert_sleepers_lie_in_fitting_ground() -> void:
	var scene = await _new_scene()
	var affinity: PackedFloat32Array = scene._drainage_affinity_snapshot()
	for species in ["grazer", "vector", "wetland_engineer"]:
		_assert(scene.sleeper_field.cells_for(species).size() >= 3, "several %s sleepers should lie on the map" % species)
	for cell in scene.sleeper_field.cells_for("wetland_engineer"):
		_assert(affinity[cell.y * scene.ecology.WIDTH + cell.x] > 0.0, "engineers should sleep where water gathers when it returns")
	var grazers: Array[Vector2i] = scene.sleeper_field.cells_for("grazer")
	for cell in grazers:
		_assert(scene.ecology.downhill_neighbor(cell) != cell, "grazers should not sleep in a hollow that holds water")
		var partnered := false
		for other in grazers:
			if other != cell and _distance(cell, other) <= 2:
				partnered = true
		_assert(partnered, "grazers should sleep in pairs")
	for cell in scene.sleeper_field.cells_for("vector") + grazers:
		_assert(cell not in scene.hoodoo_field.hoodoo_cells, "no animal should sleep inside a hoodoo")
	_assert(scene.animal_simulation.agents.is_empty(), "no animal should be awake at the start")
	_assert(not scene.grazer_root.visible, "no grazer should stand anywhere before one wakes")
	scene.queue_free()


func _assert_habitat_away_from_sleepers_wakes_nothing() -> void:
	var scene = await _new_scene()
	var far := _far_from(scene.sleeper_field.cells_for("vector"), scene, 8)
	scene.ecology.add_resources(far, {"ground_bloom": 0.16})
	scene.ecology.add_resources(far + Vector2i(2, 0), {"ground_bloom": 0.16})
	_assert(not scene._habitat_at_cell("vector", far + Vector2i(1, 0)).is_empty(), "the distant flowers should themselves be vector habitat")
	_surveys(scene, 8)
	_assert(not scene.animal_simulation.agents.has("vector:1"), "flowers far from every pupa should wake nothing; nothing walks in")
	scene.queue_free()


func _assert_vector_stirs_wakes_sleeps_and_wakes_again() -> void:
	var scene = await _new_scene()
	var pupa: Vector2i = scene.sleeper_field.cells_for("vector")[0]
	var index: int = scene.sleeper_field.index_at(pupa)
	_seed_flowers(scene, pupa)
	_surveys(scene, scene.SLEEPER_STIRRING_OBSERVATIONS)
	_assert(scene.sleeper_states[index]["state"] == "stirring", "flowers blooming around the pupae should make them stir")
	_assert(scene.sleeper_field.marker(index).get_node("Label").visible, "stirring should be visible at the pupae")
	_assert(not scene.animal_simulation.agents.has("vector:1"), "stirring pupae are not yet an animal")
	_assert(_has_event(scene.evidence.events, "organism.vector_stirring"), "stirring should be captured as evidence")
	_surveys(scene, int(scene.ARRIVAL_SUPPORT_OBSERVATIONS["vector"]) - scene.SLEEPER_STIRRING_OBSERVATIONS)
	_assert(_is_present(scene, "vector:1"), "flowers held long enough should wake the vector")
	_assert(scene.animal_simulation.agent_state("vector:1")["cell"] == pupa, "the vector should rise where it slept")
	_assert(not scene.sleeper_field.marker(index).visible, "the empty pupal cases should no longer show a sleeper")

	var lying_at := pupa + Vector2i(1, 1)
	scene.animal_simulation.agents["vector:1"]["cell"] = lying_at
	_clear_flowers(scene, pupa)
	for ignored in range(scene.DEPARTURE_GRACE_TICKS):
		scene._seed_integrated_animals()
	var sleeping: Dictionary = scene.animal_simulation.agent_state("vector:1")
	_assert(bool(sleeping["alive"]) and not bool(sleeping["present"]), "a vector whose flowers fail should go dormant, not die or leave")
	_assert(scene.sleeper_field.sleepers[index]["cell"] == lying_at, "it should go back to sleep where it was, not where it first slept")
	_assert(scene.sleeper_states[index]["state"] == "dormant" and scene.sleeper_field.marker(index).visible, "its new sleeping place should show")
	_assert(_has_event(scene.evidence.events, "organism.vector_dormant"), "going dormant should be captured as evidence")

	_seed_flowers(scene, lying_at)
	# One extra survey: the sweep under way began before the flowers returned.
	_surveys(scene, int(scene.ARRIVAL_SUPPORT_OBSERVATIONS["vector"]) + 1)
	_assert(_is_present(scene, "vector:1"), "flowers returning around it should wake it again")
	_assert(scene.animal_simulation.agent_state("vector:1")["cell"] == lying_at, "it should wake where it went to sleep")
	_assert(_has_event(scene.animal_simulation.event_history, "organism.returned"), "waking again should be recorded as a return")
	scene.queue_free()


func _assert_engineer_woken_too_early_dies() -> void:
	var scene = await _new_scene()
	var bed: Vector2i = scene.ecology.CHANNEL_CELL
	var index: int = scene.sleeper_field.index_at(bed)
	_assert(index >= 0, "an engineer should sleep in the channel bed")
	_seed_patch(scene, bed, {"surface_water": 0.18, "rhizome": 0.14, "aquatic_consumer": 0.12})
	_surveys(scene, scene.SLEEPER_STIRRING_OBSERVATIONS)
	_assert(scene.sleeper_states[index]["state"] == "stirring", "water returning through its bed should make the engineer stir")
	for y in range(bed.y - 3, bed.y + 4):
		for x in range(bed.x - 3, bed.x + 4):
			scene.ecology.consume_resource(Vector2i(x, y), "surface_water", 1.0)
			scene.ecology.consume_resource(Vector2i(x, y), "aquatic_consumer", 1.0)
	_surveys(scene, 1)
	_assert(scene.sleeper_states[index]["state"] == "dead", "an engineer whose water fails while it stirs should die")
	_assert(not scene.animal_simulation.agents.has("engineer:1"), "a sleeper dying on its first waking should leave no animal")
	_assert(scene.sleeper_field.marker(index).visible, "the dead casing should stay visible")
	_assert(_has_event(scene.evidence.events, "organism.wetland_engineer_died_waking"), "the early waking should be captured as evidence")
	scene.queue_free()


func _assert_grazer_needs_soaked_ground() -> void:
	var scene = await _new_scene()
	var shell: Vector2i = scene.sleeper_field.cells_for("grazer")[0]
	_seed_patch(scene, shell, {"moss": 0.15, "rhizome": 0.15})
	scene.ecology.add_resources(shell + Vector2i(2, 0), {"canopy": 0.22})
	_surveys(scene, int(scene.ARRIVAL_SUPPORT_OBSERVATIONS["grazer"]) + 2)
	_assert(not scene.animal_simulation.agents.has("grazer:1"), "forage alone should not wake a grazer whose ground is dry")
	var calls: int = scene._calls_per_habitat_observation()
	for ignored in range(calls * (int(scene.ARRIVAL_SUPPORT_OBSERVATIONS["grazer"]) + 1)):
		_soak(scene, shell)
		scene._seed_integrated_animals()
	_assert(_is_present(scene, "grazer:1"), "soaked ground beside forage and cover should wake the grazer")
	_assert(scene.animal_simulation.agent_state("grazer:1")["cell"] == shell, "the grazer should rise out of its shell")
	_assert(scene.grazer_root.visible, "the woken grazer should be visible")
	scene.queue_free()


# Two grazers the simulation places in the same cell are drawn apart, never
# one on top of the other.
func _assert_grazers_never_overlap() -> void:
	var scene = await _new_scene()
	var cell: Vector2i = scene.sleeper_field.cells_for("grazer")[0]
	for stable_id in ["grazer:2", "grazer:3"]:
		scene.animal_simulation.register_agent("grazer", stable_id, {"cell": cell, "habitat_cell": cell})
	scene._update_ecological_animal_markers()
	var first: Node3D = scene.animal_markers["grazer:2"]
	var second: Node3D = scene.animal_markers["grazer:3"]
	var closest := INF
	for ignored in 240:
		scene._update_grazer_markers(1.0 / 60.0)
		closest = minf(closest, Vector2(second.position.x - first.position.x, second.position.z - first.position.z).length())
	_assert(closest >= 2.0 * scene.GRAZER_BODY_RADIUS - 0.01, "two grazers in one cell should stand apart (closest %.2f m)" % closest)
	scene.queue_free()


# Shrubs grown over every forage cell, and water pooled beside the shell
# rather than on it, must still wake a grazer: more cover and more water
# never count against it.
func _assert_grazer_wakes_under_shrubs_beside_water() -> void:
	var scene = await _new_scene()
	var shell: Vector2i = scene.sleeper_field.cells_for("grazer")[0]
	_seed_patch(scene, shell, {"moss": 0.3, "rhizome": 0.3, "canopy": 0.4})
	_soak(scene, shell + Vector2i(-2, 0))
	var calls: int = scene._calls_per_habitat_observation()
	for ignored in range(calls * (int(scene.ARRIVAL_SUPPORT_OBSERVATIONS["grazer"]) + 1)):
		scene._seed_integrated_animals()
	_assert(_is_present(scene, "grazer:1"), "shrubs over the forage and water pooled beside the shell should still wake the grazer")
	scene.queue_free()


func _assert_predator_rides_the_dust() -> void:
	var scene = await _new_scene()
	var shells: Array[Vector2i] = scene.sleeper_field.cells_for("grazer").slice(0, 2)
	for shell in shells:
		scene.animal_simulation.register_agent("grazer", "grazer:%d" % (shells.find(shell) + 1), {"cell": shell, "habitat_cell": shell})
	# Fewer calls than the departure grace, so the unfed grazers stay awake.
	_surveys(scene, 1)
	_assert(not scene.animal_simulation.agents.has("predator:1"), "no predator should appear without a dust front")
	scene.disturbance_state = "warning"
	scene.disturbance_timer = 0.0
	scene._update_disturbance(0.01)
	_assert(not scene.predator_descent.is_empty(), "the front should carry a predator toward the grazers")
	var landing: Vector2i = scene.predator_descent["habitat"]["cell"]
	while scene.disturbance_column <= landing.x - 1:
		_assert(not scene.animal_simulation.agents.has("predator:1"), "the predator should not land before the dust reaches the grazers")
		scene._update_disturbance(0.1)
	_run_front(scene)
	_assert(_is_present(scene, "predator:1"), "the predator should drop out of the dust front")
	_assert(float(scene.predator_flights.get("predator:1", {"time": 0.0})["time"]) > 0.0, "it should be seen gliding in")
	_assert(_distance(scene.animal_simulation.agent_state("predator:1")["cell"], shells[0]) <= 4, "it should land on the grazers' range")

	for shell in shells:
		scene.animal_simulation.agents["grazer:%d" % (shells.find(shell) + 1)]["alive"] = false
	scene.predator_flights.clear()
	for ignored in range(scene.DEPARTURE_GRACE_TICKS):
		scene._seed_integrated_animals()
	var gone: Dictionary = scene.animal_simulation.agent_state("predator:1")
	_assert(bool(gone["alive"]) and not bool(gone["present"]), "with its prey gone the predator should climb back into the air, not die")
	_assert(float(scene.predator_flights.get("predator:1", {"time": 0.0})["time"]) < 0.0, "it should be seen gliding away")
	_assert(_has_event(scene.evidence.events, "organism.predator_dormant"), "its return to the air should be captured as evidence")
	scene.queue_free()


func _new_scene():
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	# These checks cover dying and going dormant, which the playtest setting turns off.
	scene.set_life_persists(false)
	await process_frame
	return scene


func _surveys(scene, count: int) -> void:
	for ignored in range(scene._calls_per_habitat_observation() * count):
		scene._seed_integrated_animals()


func _run_front(scene) -> void:
	for ignored in range(400):
		if scene.disturbance_state == "passed":
			return
		scene._update_disturbance(0.1)


func _seed_flowers(scene, near: Vector2i) -> void:
	scene.ecology.add_resources(near + Vector2i(-1, 1), {"ground_bloom": 0.16})
	scene.ecology.add_resources(near + Vector2i(1, 1), {"ground_bloom": 0.16})


func _clear_flowers(scene, near: Vector2i) -> void:
	for y in range(near.y - 4, near.y + 5):
		for x in range(near.x - 4, near.x + 5):
			scene.ecology.consume_resource(Vector2i(x, y), "ground_bloom", 1.0)


func _seed_patch(scene, center: Vector2i, resources: Dictionary) -> void:
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			scene.ecology.add_resources(Vector2i(x, y), resources)


func _soak(scene, center: Vector2i) -> void:
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			scene.ecology.moisture[y * scene.ecology.WIDTH + x] = 0.5


# A cell at least `gap` cells from every given cell, with room for flowers.
func _far_from(cells: Array[Vector2i], scene, gap: int) -> Vector2i:
	for y in range(2, scene.ecology.HEIGHT - 2):
		for x in range(2, scene.ecology.WIDTH - 4):
			var candidate := Vector2i(x, y)
			var clear := true
			for cell in cells:
				if _distance(candidate, cell) < gap:
					clear = false
					break
			if clear and float(scene.ecology.toxicity[y * scene.ecology.WIDTH + x]) < 0.2:
				return candidate
	return Vector2i(2, 2)


func _distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _is_present(scene, stable_id: String) -> bool:
	var agent: Dictionary = scene.animal_simulation.agent_state(stable_id)
	return not agent.is_empty() and bool(agent["alive"]) and bool(agent.get("present", true))


func _has_event(events: Array, taxonomy: String) -> bool:
	for event in events:
		if String(event["taxonomy"]) == taxonomy:
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("FAIL: " + message)
	failed = true
