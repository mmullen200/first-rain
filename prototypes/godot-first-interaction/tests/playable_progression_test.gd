extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var ecology = scene.ecology
	var weather = scene.weather_simulation
	var hollow := Vector2(-2.7, -1.55)
	var refuge := Vector2(37.0, 23.0)
	ecology.add_water(hollow)
	scene.ecology_started = true
	var milestones := {
		"rhizome": -1, "ground_flowering": -1, "colony": -1,
		"vector": -1, "canopy": -1, "grazer": -1,
		"aquatic_producer": -1, "aquatic_consumer": -1,
		"engineer": -1, "predator": -1, "first_rain": -1
	}
	var transplanted := false
	var transplant_source := Vector2i(-1, -1)
	var transplant_cell := Vector2i(-1, -1)
	var engineer_material_transferred := 0.0
	for simulation_tick in range(2400):
		if simulation_tick == 180:
			ecology.reveal_subsurface_refuge(refuge)
		if simulation_tick > 0 and simulation_tick % 90 == 0:
			var intervention_site := hollow if simulation_tick % 180 == 0 else refuge
			ecology.add_water(intervention_site, 0.72, 4.0)
		if transplanted and simulation_tick % 10 == 0 and not _is_present(scene, "vector:1"):
			ecology.add_water(ecology.world_position(transplant_source.x, transplant_source.y), 0.55, 1.2)
			ecology.add_water(ecology.world_position(transplant_cell.x, transplant_cell.y), 0.55, 1.2)
		if not transplanted and simulation_tick >= 220:
			var source := _strongest_cell(ecology, "rhizome")
			var clump: Dictionary = ecology.extract_living_clump(source)
			if not clump.is_empty() and String(clump["resource"]) == "rhizome":
				transplant_source = source
				transplant_cell = Vector2i(clampi(source.x + 3, 0, ecology.WIDTH - 1), source.y)
				ecology.place_living_clump(transplant_cell, "rhizome", float(clump["amount"]))
				transplanted = true
		if int(milestones["grazer"]) >= 0 and not _is_present(scene, "engineer:1"):
			var channel: Vector2i = ecology.CHANNEL_CELL
			if simulation_tick % 30 == 0:
				ecology.add_water(ecology.world_position(channel.x, channel.y), 0.65, 1.5)
			if engineer_material_transferred < 0.5:
				var source := _strongest_cell(ecology, "rhizome")
				var clump: Dictionary = ecology.extract_living_clump(source)
				if not clump.is_empty() and String(clump["resource"]) == "rhizome":
					engineer_material_transferred += ecology.place_living_clump(channel, "rhizome", float(clump["amount"]))
		if int(milestones["aquatic_consumer"]) >= 0 and not _is_present(scene, "engineer:1"):
			var channel: Vector2i = ecology.CHANNEL_CELL
			ecology.add_water(ecology.world_position(channel.x, channel.y), 0.65, 1.5)

		scene._seed_integrated_animals()
		var animal_events: Array[Dictionary] = scene.animal_simulation.step()
		scene._handle_authoritative_animal_events(animal_events)
		scene._update_grazer(scene.ECOLOGY_STEP_SECONDS)
		var state: Dictionary = ecology.summary()
		var weather_events: Array[Dictionary] = weather.step(state)
		scene._handle_weather_events(weather_events)
		scene._update_disturbance(scene.ECOLOGY_STEP_SECONDS)
		if weather.precipitation > 0.0:
			ecology.add_water(Vector2(16.0, 10.0), weather.precipitation * 0.04, 58.0)

		_record_ecological_milestones(milestones, state, simulation_tick)
		_record_animal_milestones(milestones, scene, simulation_tick)
		if milestones["first_rain"] < 0 and weather.first_rain_reached:
			milestones["first_rain"] = simulation_tick

	print("Playable progression observations: ", milestones)
	_assert(transplanted, "finite rooted biomass was never robust enough to transplant into a separated patch")
	for milestone in milestones:
		_assert(int(milestones[milestone]) >= 0, "playable succession never reached %s" % String(milestone).replace("_", " "))
	_assert(int(milestones["aquatic_producer"]) < int(milestones["aquatic_consumer"]), "aquatic consumers appeared before producers")
	_assert(int(milestones["first_rain"]) > int(milestones["aquatic_consumer"]), "First Rain occurred before the aquatic food web processed sulfur")
	if failed:
		quit(1)
	else:
		print("PASS: finite watering and transplantation produce habitat-supported animals, the parallel aquatic sulfur pathway, and First Rain: ", milestones)
		quit(0)


func _record_ecological_milestones(milestones: Dictionary, state: Dictionary, simulation_tick: int) -> void:
	var observations := {
		"rhizome": int(state["rhizome_cells"]) >= 1,
		"ground_flowering": float(state["total_ground_bloom"]) >= 0.012,
		"canopy": int(state["canopy_cells"]) >= 1,
		"aquatic_producer": int(state["aquatic_cells"]) >= 1,
		"aquatic_consumer": int(state["aquatic_consumer_cells"]) >= 1
	}
	for milestone in observations:
		if int(milestones[milestone]) < 0 and bool(observations[milestone]):
			milestones[milestone] = simulation_tick


func _record_animal_milestones(milestones: Dictionary, scene, simulation_tick: int) -> void:
	var ids := {
		"colony": "colony:1", "vector": "vector:1", "grazer": "grazer:1",
		"engineer": "engineer:1", "predator": "predator:1"
	}
	for milestone in ids:
		if int(milestones[milestone]) < 0 and _is_present(scene, ids[milestone]):
			milestones[milestone] = simulation_tick


func _is_present(scene, stable_id: String) -> bool:
	var agent: Dictionary = scene.animal_simulation.agent_state(stable_id)
	return not agent.is_empty() and bool(agent["alive"]) and bool(agent.get("present", true))


func _strongest_cell(ecology, resource: String) -> Vector2i:
	var best := Vector2i.ZERO
	var best_amount := -1.0
	for y in range(ecology.HEIGHT):
		for x in range(ecology.WIDTH):
			var cell := Vector2i(x, y)
			var amount: float = ecology.resource_amount(cell, resource)
			if amount > best_amount:
				best_amount = amount
				best = cell
	return best


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("FAIL: " + message)
	failed = true
