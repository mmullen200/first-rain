extends SceneTree

const EcologyGrid = preload("res://ecology_grid.gd")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_fungus_needs_detritus()
	_assert_rooted_mats_need_both_pioneers()
	_assert_canopy_waits_for_pollination()
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	# Every animal habitat exists at once. Ecological prerequisites, rather than
	# scan order or shared abundance, must still establish one role at a time.
	var colony_patch := Vector2i(21, 13)
	_seed_patch(scene, colony_patch, {"dead_biomass": 0.2}, 1)
	var flower_patch := Vector2i(4, 12)
	scene.ecology.add_resources(flower_patch, {"ground_bloom": 0.16})
	scene.ecology.add_resources(flower_patch + Vector2i(2, 0), {"ground_bloom": 0.16})
	var grazer_patch := Vector2i(3, 13)
	_seed_patch(scene, grazer_patch, {"moss": 0.15, "rhizome": 0.15}, 1)
	scene.ecology.add_shade(scene.ecology.world_position(grazer_patch.x + 2, grazer_patch.y), 0.8, 1.5)
	var engineer_patch: Vector2i = scene.ecology.CHANNEL_CELL
	_seed_patch(scene, engineer_patch, {"surface_water": 0.18, "rhizome": 0.14}, 1)

	_advance_until_agent_count(scene, 1)
	_assert(_living_species(scene) == ["colony"], "the eusocial colony should be the only first animal even when every later habitat already exists")
	_advance_until_agent_count(scene, 2)
	_assert(_living_species(scene) == ["colony", "vector"], "the flying reproductive vector should follow the colony")
	_advance_search_attempts(scene)
	_assert(_living_species(scene) == ["colony", "vector"], "physical shade should not let a grazer arrive before canopy establishes")
	scene.ecology.add_resources(grazer_patch + Vector2i(2, 0), {"canopy": 0.22})
	_advance_until_agent_count(scene, 3)
	_assert(_living_species(scene) == ["colony", "grazer", "vector"], "the first grazer should follow flowering, pollination, and canopy")
	_advance_until_agent_count(scene, 4)
	_assert(_living_species(scene) == ["colony", "grazer", "grazer", "vector"], "a viable grazer population should establish before its predator")
	_advance_search_attempts(scene)
	_assert(_living_species(scene) == ["colony", "grazer", "grazer", "vector"], "a wet planted channel should not admit a Wetland Engineer before aquatic consumers establish")
	_seed_patch(scene, engineer_patch, {"aquatic_consumer": 0.12}, 1)
	_advance_until_agent_count(scene, 5)
	_assert(_living_species(scene) == ["colony", "grazer", "grazer", "vector", "wetland_engineer"], "the Wetland Engineer should arrive after the grazer")
	_advance_until_agent_count(scene, 6)
	_assert(_living_species(scene) == ["colony", "grazer", "grazer", "predator", "vector", "wetland_engineer"], "the predator should be the final animal to establish")

	if failed:
		quit(1)
	else:
		print("PASS: animal establishment proceeds from colony through vector, grazers, Wetland Engineer, and predator")
		quit(0)


func _assert_fungus_needs_detritus() -> void:
	var ecology = EcologyGrid.new()
	var cell: Vector2i = EcologyGrid.CLOSED_HOLLOW_CELL
	var world: Vector2 = ecology.world_position(cell.x, cell.y)
	ecology.add_resources(cell, {"fungal_spores": 0.7, "nutrients": 0.5})
	for ignored in range(25):
		ecology.add_water(world, 0.35, 1.5)
		ecology.step()
	_assert(ecology.resource_amount(cell, "fungus") == 0.0, "wet spores should not establish fungus where there is no Detritus")
	ecology.add_resources(cell, {"dead_biomass": 0.3, "fungal_spores": 0.7})
	for ignored in range(25):
		ecology.add_water(world, 0.35, 1.5)
		ecology.step()
	_assert(ecology.resource_amount(cell, "fungus") > 0.0, "wet Detritus should let fungal spores establish")


func _assert_rooted_mats_need_both_pioneers() -> void:
	var ecology = EcologyGrid.new()
	var cell: Vector2i = EcologyGrid.CLOSED_HOLLOW_CELL
	var world: Vector2 = ecology.world_position(cell.x, cell.y)
	ecology.add_resources(cell, {
		"moss": 0.4,
		"nutrients": 0.8,
		"dormant_rhizome": 0.8
	})
	for ignored in range(30):
		ecology.add_water(world, 0.35, 1.5)
		ecology.step()
	_assert(ecology.resource_amount(cell, "rhizome") == 0.0, "abundant moss should not substitute for missing microbial crust when rooted mats wake")
	ecology.add_resources(cell, {"microbial_crust": 0.2})
	for ignored in range(30):
		ecology.add_water(world, 0.35, 1.5)
		ecology.step()
	_assert(ecology.resource_amount(cell, "rhizome") > 0.0, "moss, microbial crust, and nutrients together should wake rooted mats")


func _assert_canopy_waits_for_pollination() -> void:
	var ecology = EcologyGrid.new()
	var cell: Vector2i = EcologyGrid.CLOSED_HOLLOW_CELL
	var world: Vector2 = ecology.world_position(cell.x, cell.y)
	ecology.add_resources(cell, {
		"moss": 0.4,
		"fungus": 0.35,
		"nutrients": 0.8,
		"rhizome": 0.45,
		"dormant_canopy": 0.8
	})
	for ignored in range(40):
		ecology.add_water(world, 0.35, 1.5)
		ecology.step()
	_assert(ecology.resource_amount(cell, "canopy") == 0.0, "canopy should remain dormant while flowering plants have no flying-vector pollination")
	ecology.add_resources(cell, {"pollination": 0.3})
	for ignored in range(40):
		ecology.add_water(world, 0.35, 1.5)
		ecology.step()
	_assert(ecology.resource_amount(cell, "canopy") > 0.0, "pollination should let suitable dormant canopy wake")


func _advance_until_agent_count(scene, expected_count: int) -> void:
	for ignored in range(40):
		scene._seed_integrated_animals()
		if scene.animal_simulation.agents.size() >= expected_count:
			return


func _advance_search_attempts(scene) -> void:
	for ignored in range(40):
		scene._seed_integrated_animals()


func _living_species(scene) -> Array[String]:
	var result: Array[String] = []
	for stable_id in scene.animal_simulation.agents:
		var agent: Dictionary = scene.animal_simulation.agent_state(stable_id)
		if bool(agent["alive"]):
			result.append(String(agent["species"]))
	result.sort()
	return result


func _seed_patch(scene, center: Vector2i, resources: Dictionary, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			scene.ecology.add_resources(Vector2i(x, y), resources)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("FAIL: " + message)
	failed = true
