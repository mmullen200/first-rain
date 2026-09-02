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
	_assert(uniform_scene._best_arrival_habitat("colony").is_empty(), "wet Detritus in one lush patch should not qualify the dry-ground colony")
	_assert(uniform_scene._best_arrival_habitat("vector").is_empty(), "one connected bloom carpet should not qualify a reproductive vector")
	_assert(uniform_scene._best_arrival_habitat("wetland_engineer").is_empty(), "standing water away from the Drainage Spine should not qualify a Wetland Engineer")
	_assert(uniform_scene._best_arrival_habitat("grazer").is_empty(), "uniform forage under uniform cover should not qualify a grazer without a habitat edge")
	uniform_scene.queue_free()

	var colony_patch := Vector2i(21, 13)
	_seed_patch(scene, colony_patch, {"dead_biomass": 0.2}, 1)
	var colony_habitat: Dictionary = scene._best_arrival_habitat("colony")
	_assert(not colony_habitat.is_empty(), "a concentrated fairly dry detritus patch should qualify for colony arrival")
	_assert(_cell_distance(colony_habitat["cell"], colony_patch) <= 1, "the colony destination should follow the local detritus patch")
	_assert(colony_habitat["cell"] != Vector2i(10, 8), "the old hardcoded colony cell should not control arrival")

	var vector_patch := Vector2i(4, 12)
	scene.ecology.add_resources(vector_patch, {"ground_bloom": 0.16})
	scene.ecology.add_resources(vector_patch + Vector2i(2, 0), {"canopy_bloom": 0.16})
	var vector_habitat: Dictionary = scene._best_arrival_habitat("vector")
	_assert(not vector_habitat.is_empty(), "two nearby flowering patches should qualify for vector arrival")
	_assert(_cell_distance(vector_habitat["cell"], vector_patch + Vector2i(1, 0)) <= 3, "the vector destination should follow connected blossoms")

	var engineer_patch: Vector2i = scene.ecology.CHANNEL_CELL
	_seed_patch(scene, engineer_patch, {"surface_water": 0.18, "rhizome": 0.14}, 1)
	var engineer_habitat: Dictionary = scene._best_arrival_habitat("wetland_engineer")
	_assert(not engineer_habitat.is_empty(), "water and plants on the Drainage Spine should qualify for engineer arrival")
	_assert(_cell_distance(engineer_habitat["cell"], engineer_patch) <= 1, "the engineer destination should follow the local wetland")

	var grazer_patch := Vector2i(3, 13)
	_seed_patch(scene, grazer_patch, {"moss": 0.15, "rhizome": 0.15}, 1)
	scene.ecology.add_resources(grazer_patch + Vector2i(2, 0), {"canopy": 0.22})
	var grazer_habitat: Dictionary = scene._best_arrival_habitat("grazer")
	_assert(not grazer_habitat.is_empty(), "concentrated open forage beside cover should qualify for grazer arrival")
	_assert(_cell_distance(grazer_habitat["cell"], grazer_patch) <= 1, "the grazer destination should follow local forage")

	scene.grazer_awake = true
	scene.animal_simulation.register_agent("grazer", "grazer:1", {"cell": grazer_patch})
	for ignored in range(20):
		scene._seed_integrated_animals()
	_assert(scene.animal_simulation.agents.has("colony:1"), "qualifying local habitat should establish the colony")
	_assert(scene.animal_simulation.agents.has("vector:1"), "separated flowering patches should establish a reproductive vector")
	_assert(scene.animal_simulation.agents.has("engineer:1"), "a planted wet Drainage Spine should establish a Wetland Engineer")
	_assert(scene.animal_simulation.agents.has("grazer:2"), "open forage beside cover should establish the second grazer")
	_assert(scene.animal_simulation.agents.has("predator:1"), "two living grazers should establish a nearby predator")
	_assert(scene.animal_simulation.agent_state("colony:1")["cell"] == colony_habitat["cell"], "registration should use the selected local colony habitat")
	_assert(not _discoveries_explain_roles(scene.discoveries), "arrival discoveries should describe evidence without announcing ecological functions")

	if failed:
		quit(1)
	else:
		print("PASS: species require contrasting local habitat and arrive without role-explaining discovery text")
		quit(0)


func _seed_patch(scene, center: Vector2i, resources: Dictionary, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			scene.ecology.add_resources(Vector2i(x, y), resources)


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
