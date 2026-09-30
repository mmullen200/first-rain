extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	var uniform_scene = load("res://main.tscn").instantiate()
	root.add_child(uniform_scene)
	await process_frame
	var lush_patch := Vector2i(12, 3)
	_seed_patch(uniform_scene, lush_patch, {
		"dead_biomass": 0.2,
		"surface_water": 0.18,
		"moss": 0.15,
		"rhizome": 0.15,
		"canopy": 0.1,
		"ground_bloom": 0.08,
		"canopy_bloom": 0.08
	}, 1)
	uniform_scene.ecology.add_water(uniform_scene.ecology.world_position(lush_patch.x, lush_patch.y), 0.5, 2.4)
	_assert(uniform_scene._best_arrival_habitat("vector").is_empty(), "one connected bloom carpet should not qualify a reproductive vector")
	_assert(uniform_scene._best_arrival_habitat("wetland_engineer").is_empty(), "standing water away from the Drainage Spine should not qualify a Wetland Engineer")
	# Reversed 2026-09-30 (user): too many shrubs must never keep a grazer from waking.
	_assert(not uniform_scene._best_arrival_habitat("grazer").is_empty(), "forage under shrub cover should qualify a grazer")
	uniform_scene.queue_free()

	# Nothing arrives. The colony wakes from a queen sleeping in a hoodoo, and
	# every other animal from a sleeper lying near its habitat.
	var queen: Vector2i = scene.hoodoo_field.queen_cells[1]
	_seed_patch(scene, queen, {"fungus": 0.2, "dead_biomass": 0.2}, 1)

	var vector_sleeper: Vector2i = scene.sleeper_field.cells_for("vector")[0]
	var vector_patch := vector_sleeper + Vector2i(-1, 1)
	scene.ecology.add_resources(vector_patch, {"ground_bloom": 0.16})
	scene.ecology.add_resources(vector_patch + Vector2i(2, 0), {"ground_bloom": 0.16})
	var vector_habitat: Dictionary = scene._best_arrival_habitat("vector")
	_assert(not vector_habitat.is_empty(), "two nearby flowering patches should qualify as vector habitat")
	_assert(_cell_distance(vector_habitat["cell"], vector_patch + Vector2i(1, 0)) <= 3, "the vector habitat should follow connected blossoms")

	var engineer_patch: Vector2i = scene.ecology.CHANNEL_CELL
	_assert(engineer_patch in scene.sleeper_field.cells_for("wetland_engineer"), "an engineer should sleep in the channel bed through Long Meadow")
	_seed_patch(scene, engineer_patch, {"surface_water": 0.18, "rhizome": 0.14, "aquatic_consumer": 0.12}, 1)
	var engineer_habitat: Dictionary = scene._best_arrival_habitat("wetland_engineer")
	_assert(not engineer_habitat.is_empty(), "water and plants on the Drainage Spine should qualify as engineer habitat")
	_assert(_cell_distance(engineer_habitat["cell"], engineer_patch) <= 1, "the engineer habitat should follow the local wetland")

	var grazer_sleepers: Array[Vector2i] = _closest_pair(scene.sleeper_field.cells_for("grazer"))
	for grazer_patch in grazer_sleepers:
		_seed_patch(scene, grazer_patch, {"moss": 0.15, "rhizome": 0.15}, 1)
		scene.ecology.add_resources(grazer_patch + Vector2i(2, 0), {"canopy": 0.22})
	var grazer_habitat: Dictionary = scene._best_arrival_habitat("grazer")
	_assert(not grazer_habitat.is_empty(), "concentrated open forage beside cover should qualify as grazer habitat")

	for ignored in range(520):
		for grazer_patch in grazer_sleepers:
			_soak(scene, grazer_patch)
		scene._seed_integrated_animals()
	_assert(scene.animal_simulation.agents.has("colony:1"), "fungus beside a queen's hoodoo should wake the colony")
	_assert(scene.animal_simulation.agents.has("vector:1"), "separated flowering patches should wake a vector sleeping among them")
	_assert(scene.animal_simulation.agents.has("engineer:1"), "a planted wet Drainage Spine should wake the engineer sleeping in its bed")
	_assert(scene.animal_simulation.agents.has("grazer:1") and scene.animal_simulation.agents.has("grazer:2"), "soaked forage beside cover should wake both buried grazers")
	_assert(not scene.animal_simulation.agents.has("predator:1"), "a predator should not appear without a dust front")
	_bring_dust_front(scene)
	_assert(scene.animal_simulation.agents.has("predator:1"), "a dust front over two living grazers should bring a predator down")
	var nest: Vector2i = scene.animal_simulation.agent_state("colony:1")["cell"]
	_assert(maxi(absi(nest.x - queen.x), absi(nest.y - queen.y)) == 1, "the colony should found its nest beside the queen's hoodoo, not anywhere in the basin")
	_assert(not _discoveries_explain_roles(scene.discoveries), "waking discoveries should describe evidence without announcing ecological functions")

	if failed:
		quit(1)
	else:
		print("PASS: species require contrasting local habitat and arrive without role-explaining discovery text")
		quit(0)


func _seed_patch(scene, center: Vector2i, resources: Dictionary, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			scene.ecology.add_resources(Vector2i(x, y), resources)


# Two grazers must live near each other before a predator will come down.
func _closest_pair(cells: Array[Vector2i]) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	var best_distance := 1 << 30
	for a in range(cells.size()):
		for b in range(a + 1, cells.size()):
			var distance := maxi(absi(cells[a].x - cells[b].x), absi(cells[a].y - cells[b].y))
			if distance < best_distance:
				best_distance = distance
				best = [cells[a], cells[b]]
	return best


func _soak(scene, center: Vector2i) -> void:
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			scene.ecology.moisture[y * scene.ecology.WIDTH + x] = 0.5


func _bring_dust_front(scene) -> void:
	scene.disturbance_state = "warning"
	scene.disturbance_timer = 0.0
	scene._update_disturbance(0.01)
	for ignored in range(400):
		if scene.disturbance_state == "passed":
			return
		scene._update_disturbance(0.1)


func _discoveries_explain_roles(discoveries: Array[String]) -> bool:
	for discovery in discoveries:
		var lower := discovery.to_lower()
		if "recycles detritus" in lower or "limits grazer pressure" in lower or "makes mating" in lower or "converts gathered biomass" in lower or "carries reproductive material" in lower:
			return true
	return false


func _cell_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("FAIL: " + message)
	failed = true
