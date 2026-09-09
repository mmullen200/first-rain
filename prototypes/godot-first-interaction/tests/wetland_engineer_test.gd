extends SceneTree

const Grid = preload("res://ecology_grid.gd")
const Animals = preload("res://animal_simulation.gd")
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var grid = Grid.new()
	var home := Vector2i(9, 7)
	var flow_site := Vector2i(8, 7)
	var stick_site := Vector2i(11, 8)
	grid.throughflow[flow_site.y * grid.WIDTH + flow_site.x] = 0.3
	grid.throughflow[stick_site.y * grid.WIDTH + stick_site.x] = 0.01
	grid.add_resources(stick_site, {"dead_biomass": 0.35})
	var simulation = Animals.new(grid, 91)
	check(simulation.register_agent("wetland_engineer", "engineer:1", {"cell": stick_site, "habitat_cell": home}), "engineer registration failed")
	check(simulation.best_engineer_build_site(home) == flow_site, "strongest local flow was not selected")
	for ignored in range(80):
		# Hold the controlled flow signal while the animal gathers and hauls.
		grid.throughflow[flow_site.y * grid.WIDTH + flow_site.x] = 0.3
		simulation.tick += 1
		var intention: Dictionary = simulation._choose_engineer_intention(simulation.agents["engineer:1"])
		simulation._resolve_intention(intention)
	check(grid.resource_amount(flow_site, "dam_material") > 0.0, "material was not carried from its source to the selected flow site")
	check(grid.resource_amount(stick_site, "dam_material") == 0.0, "engineer built where material was gathered")

	var depth_neighbor := flow_site + Vector2i(-1, 0)
	grid.surface_water[flow_site.y * grid.WIDTH + flow_site.x] = Animals.ENGINEER_TARGET_DEPTH + 0.1
	grid.dead_biomass[stick_site.y * grid.WIDTH + stick_site.x] = 0.3
	simulation.agents["engineer:1"]["move_cooldown"] = 0
	simulation.agents["engineer:1"]["carried_material"] = {}
	var material_before := grid.resource_amount(stick_site, "dead_biomass")
	var stop_intention: Dictionary = simulation._choose_engineer_intention(simulation.agents["engineer:1"])
	check(stop_intention["type"] == "wait" and simulation.agent_state("engineer:1")["state"] == "tending pond", "engineer did not stop at target depth")
	check(grid.resource_amount(stick_site, "dead_biomass") == material_before, "depth-satisfied engineer gathered more material")

	grid.surface_water[flow_site.y * grid.WIDTH + flow_site.x] = 0.0
	grid.dam_material[flow_site.y * grid.WIDTH + flow_site.x] = Animals.ENGINEER_TARGET_DAM
	for ignored in range(20):
		grid.step()
	grid.throughflow[flow_site.y * grid.WIDTH + flow_site.x] = 0.3
	simulation.agents["engineer:1"]["move_cooldown"] = 0
	var repair_intention: Dictionary = simulation._choose_engineer_intention(simulation.agents["engineer:1"])
	check(repair_intention["type"] in ["move", "gather"], "engineer did not resume work after dam decay and depth loss")

	var abandoned = Grid.new()
	abandoned.dam_material[flow_site.y * abandoned.WIDTH + flow_site.x] = 0.5
	abandoned.surface_water[depth_neighbor.y * abandoned.WIDTH + depth_neighbor.x] = 0.65
	var initial_dam := abandoned.resource_amount(flow_site, "dam_material")
	var initial_pond := abandoned.resource_amount(depth_neighbor, "surface_water")
	var initial_detritus := abandoned.resource_amount(flow_site, "dead_biomass")
	for ignored in range(240):
		abandoned.step()
	check(abandoned.resource_amount(flow_site, "dam_material") < initial_dam * 0.5, "abandoned dam did not substantially decay")
	check(abandoned.resource_amount(depth_neighbor, "surface_water") < initial_pond * 0.2, "pond did not drain after abandonment")
	check(abandoned.resource_amount(flow_site, "dead_biomass") > initial_detritus, "decayed dam material did not enter Detritus")

	var replay = Animals.new(Grid.new(), 1)
	check(replay.restore(simulation.snapshot()), "engineer snapshot restore failed")
	for ignored in range(40):
		simulation.step()
		replay.step()
	check(simulation.snapshot() == replay.snapshot(), "engineer site and maintenance replay diverged")

	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene._seed_engineer_fixture()
	scene._open_emergency_cache()
	var scene_home := Vector2i(8, 8)
	var old_site := Vector2i(7, 8)
	var cut_site := Vector2i(9, 8)
	var site_reader = Animals.new(scene.ecology, 7)
	check(site_reader.best_engineer_build_site(scene_home) == old_site, "fixture did not begin with the old audible flow")
	scene.animal_simulation.agents["engineer:1"]["move_cooldown"] = 0
	scene.animal_simulation._choose_engineer_intention(scene.animal_simulation.agents["engineer:1"])
	check(scene.animal_simulation.agent_state("engineer:1")["build_cell"] == old_site, "fixture engineer did not initially select the existing flow")
	var elevation_before: float = scene.ecology.terrain_height(cut_site)
	scene._excavate_nearby_cell()
	check(scene.ecology.terrain_height(cut_site) < elevation_before, "G excavation did not lower the dry lip")
	scene.ecology.step()
	check(site_reader.best_engineer_build_site(scene_home) == cut_site, "player excavation did not redirect strongest flow to the cut")
	scene.animal_simulation.agents["engineer:1"]["move_cooldown"] = 0
	scene.animal_simulation._choose_engineer_intention(scene.animal_simulation.agents["engineer:1"])
	check(scene.animal_simulation.agent_state("engineer:1")["build_cell"] == cut_site, "fixture engineer did not adopt the player-created flow site")
	check(scene.animal_simulation.agent_state("engineer:1")["habitat_cell"] == cut_site, "fixture engineer residency did not follow its active dam site")
	var reached_cut := false
	var remained_present := true
	for ignored in range(100):
		scene._seed_integrated_animals()
		scene.animal_simulation.step()
		var engineer: Dictionary = scene.animal_simulation.agent_state("engineer:1")
		if bool(engineer.get("present", false)) and engineer.get("cell", Vector2i(-1, -1)) == cut_site:
			reached_cut = true
		if reached_cut and not bool(engineer.get("present", false)):
			remained_present = false
			break
	check(reached_cut, "fixture engineer never reached the player-cut square")
	check(remained_present, "fixture engineer departed after adopting an active dam site")
	scene.queue_free()
	await process_frame
	if not failed:
		print("PASS: flow-selected dam site, remote hauling, depth stop, maintenance, reversible abandonment and replay")
	quit(1 if failed else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL: " + message)
