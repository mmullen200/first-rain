extends SceneTree

const EcologyGridModel = preload("res://ecology_grid.gd")
const AnimalSimulation = preload("res://animal_simulation.gd")
const GardenSpire = preload("res://garden_spire.gd")

var failed := false


func _initialize() -> void:
	_check_colony_farms_what_workers_bring_home()
	_check_garden_fails_without_food()
	_check_hoodoo_rings_record_the_hoodoo()
	_check_spire_grows_from_its_history()
	if failed:
		quit(1)
	else:
		print("PASS: the colony tends carried matter into a fungus garden, eats from it, seeds fungus onto its nest and lets it fail when food stops; its hanging garden grows like tree rings that point toward the food, record a hoodoo diet, differ between histories and are lost from the top")
		quit(0)


# Watered plants in reach: the garden grows beyond the queen's pellet, the
# colony eats from it, and living fungus appears on the nest ground.
func _check_colony_farms_what_workers_bring_home() -> void:
	var ecology = EcologyGridModel.new()
	var home := Vector2i(30, 12)
	# Plants only to the east, so the rings should reach east.
	for y in range(home.y - 3, home.y + 4):
		for x in range(home.x + 1, home.x + 4):
			ecology.add_resources(Vector2i(x, y), {"moss": 0.5, "rhizome": 0.5, "nutrients": 0.3})
	var simulation = AnimalSimulation.new(ecology, 11)
	simulation.register_agent("colony", "colony:1", {"cell": home})
	_assert(is_equal_approx(float(simulation.agents["colony:1"]["garden"]), AnimalSimulation.COLONY_FOUNDING_PELLET), "a new colony should start from the queen's pellet of fungus")
	var fungus_before: float = ecology.resource_amount(home, "fungus")
	var eaten := 0.0
	var tended := 0.0
	for tick in range(1500):
		if tick % 10 == 0:
			_water(ecology, home)
		for event in simulation.step():
			if event["taxonomy"] == "organism.colony_garden_tended":
				eaten += float(event["facts"]["eaten"])
				tended += float(event["facts"]["tended"])
	var garden := float(simulation.agents["colony:1"]["garden"])
	_assert(tended > 0.05, "workers' plant matter should be tended into the garden (%.3f)" % tended)
	_assert(garden > AnimalSimulation.COLONY_FOUNDING_PELLET * 2.0, "a colony with plants in reach should grow its garden well past the pellet (%.3f)" % garden)
	_assert(eaten > 0.0, "the colony should eat from its garden")
	_assert(ecology.resource_amount(home, "fungus") > fungus_before, "the garden should seed living fungus onto the nest ground")
	_assert(simulation.conservation_violations.is_empty(), "farming should conserve material: %s" % [simulation.conservation_violations])
	var fed_rings := _informed_rings(simulation.agents["colony:1"]["terraces"])
	_assert(fed_rings.size() >= 3, "a well-fed garden should lay several terraces from its history (%d)" % fed_rings.size())
	for ring in fed_rings:
		_assert(cos(float(ring["heading"])) > 0.5, "rings should reach toward food to the east (heading %.2f)" % float(ring["heading"]))
		_assert(float(ring["hoodoo_share"]) < 0.1, "rings laid on plants should not be marked as hoodoo")


# Rings laid after food started coming home. The first rings from the queen's
# pellet carry no history.
func _informed_rings(terraces: Array) -> Array:
	var informed := []
	for ring in terraces:
		if float(ring["richness"]) > 0.0:
			informed.append(ring)
	return informed


# Living only off a hoodoo to the west, the colony's rings record hoodoo and
# point west.
func _check_hoodoo_rings_record_the_hoodoo() -> void:
	var ecology = EcologyGridModel.new()
	var home := Vector2i(30, 12)
	var hoodoo := home + Vector2i(-2, 0)
	ecology.add_resources(hoodoo, {"old_matter": 0.4})
	var simulation = AnimalSimulation.new(ecology, 5)
	simulation.register_agent("colony", "colony:1", {"cell": home, "garden": 0.0})
	for ignored in range(1200):
		simulation.step()
	var rings := _informed_rings(simulation.agents["colony:1"]["terraces"])
	_assert(not rings.is_empty(), "a colony living on a hoodoo should lay at least one ring")
	for ring in rings:
		_assert(float(ring["hoodoo_share"]) > 0.9, "rings laid on hoodoo should record it (%.2f)" % float(ring["hoodoo_share"]))
		_assert(cos(float(ring["heading"])) < -0.5, "rings should reach toward the hoodoo to the west (heading %.2f)" % float(ring["heading"]))


# Water only the planted east side, so nothing grows to the west.
func _water(ecology, home: Vector2i) -> void:
	for y in range(home.y - 3, home.y + 4):
		for x in range(home.x + 1, home.x + 4):
			var index: int = y * ecology.WIDTH + x
			ecology.moisture[index] = 0.55
			ecology.temperature[index] = 0.4
			ecology.toxicity[index] = 0.05


# Nothing to bring home: the pellet is eaten down and the garden fails.
func _check_garden_fails_without_food() -> void:
	var ecology = EcologyGridModel.new()
	var home := Vector2i(30, 12)
	for y in range(home.y - 7, home.y + 8):
		for x in range(home.x - 7, home.x + 8):
			for resource in ["moss", "rhizome", "dead_biomass", "old_matter"]:
				ecology.consume_resource(Vector2i(x, y), resource, 1.0)
	var simulation = AnimalSimulation.new(ecology, 11)
	simulation.register_agent("colony", "colony:1", {"cell": home})
	for ignored in range(1500):
		simulation.step()
	_assert(float(simulation.agents["colony:1"]["garden"]) < AnimalSimulation.COLONY_FOUNDING_PELLET * 0.5, "a garden with no food coming home should be eaten down")


func _ring(heading: float, richness: float, hoodoo_share: float, seed: int) -> Dictionary:
	return {"heading": heading, "richness": richness, "hoodoo_share": hoodoo_share, "damp_heading": heading + 1.0, "seed": seed}


func _check_spire_grows_from_its_history() -> void:
	var plenty: Array = []
	var hardship: Array = []
	for index in range(8):
		plenty.append(_ring(0.0, 0.9, 0.0, 100 + index))
		hardship.append(_ring(PI, 0.15, 1.0, 100 + index))
	var rich_spire = GardenSpire.new()
	rich_spire.set_terraces(plenty)
	var lean_spire = GardenSpire.new()
	lean_spire.set_terraces(hardship)
	_assert(rich_spire.terrace_nodes.size() == 8, "each ring should become one terrace")
	_assert(rich_spire.centres[-1].x > 0.0 and lean_spire.centres[-1].x < 0.0, "towers should lean toward where their food came from")
	_assert(_band_width(rich_spire) > _band_width(lean_spire) * 1.5, "plenty should lay wider terraces than hardship")
	_assert(_band_colour(rich_spire) != _band_colour(lean_spire), "hoodoo and plant diets should colour the terraces differently")
	var reseeded: Array = []
	for index in range(8):
		reseeded.append(_ring(0.0, 0.9, 0.0, 900 + index))
	var twin = GardenSpire.new()
	twin.set_terraces(reseeded)
	_assert(twin.start_angles != rich_spire.start_angles, "two colonies with the same kind of life should still grow different towers")
	rich_spire.set_terraces(plenty.slice(0, 3))
	_assert(rich_spire.terrace_nodes.size() == 3 and rich_spire.falling.size() == 5, "a shrinking garden should lose terraces from the top")
	for spire in [rich_spire, lean_spire, twin]:
		spire.free()


func _band_width(spire) -> float:
	var band: MeshInstance3D = spire.terrace_nodes[3].get_child(0)
	var box: AABB = band.mesh.get_aabb()
	return box.size.x + box.size.z


func _band_colour(spire) -> Color:
	var band: MeshInstance3D = spire.terrace_nodes[3].get_child(0)
	return band.material_override.albedo_color


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL: ", message)
