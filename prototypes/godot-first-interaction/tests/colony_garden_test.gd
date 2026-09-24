extends SceneTree

const EcologyGridModel = preload("res://ecology_grid.gd")
const AnimalSimulation = preload("res://animal_simulation.gd")
const GardenSpire = preload("res://garden_spire.gd")

var failed := false


func _initialize() -> void:
	_check_colony_farms_what_workers_bring_home()
	_check_garden_fails_without_food()
	_check_spire_follows_the_garden()
	if failed:
		quit(1)
	else:
		print("PASS: the colony tends carried matter into a fungus garden, eats from the garden, seeds fungus onto its nest, lets the garden fail when food stops, and its hanging spire rises and sinks with the garden")
		quit(0)


# Watered plants in reach: the garden grows beyond the queen's pellet, the
# colony eats from it, and living fungus appears on the nest ground.
func _check_colony_farms_what_workers_bring_home() -> void:
	var ecology = EcologyGridModel.new()
	var home := Vector2i(30, 12)
	for y in range(home.y - 3, home.y + 4):
		for x in range(home.x - 3, home.x + 4):
			var cell := Vector2i(x, y)
			if cell != home:
				ecology.add_resources(cell, {"moss": 0.5, "rhizome": 0.5, "nutrients": 0.3})
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


func _water(ecology, home: Vector2i) -> void:
	for y in range(home.y - 3, home.y + 4):
		for x in range(home.x - 3, home.x + 4):
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


func _check_spire_follows_the_garden() -> void:
	var spire = GardenSpire.new()
	spire.set_growth(1.0)
	for ignored in range(400):
		spire._process(0.05)
	var standing := 0
	for segment in spire.segments:
		standing += 1 if segment.visible else 0
	_assert(standing == spire.segments.size(), "a full garden should raise the whole spire")
	spire.set_growth(0.2)
	for ignored in range(400):
		spire._process(0.05)
	var remaining := 0
	for segment in spire.segments:
		remaining += 1 if segment.visible else 0
	_assert(remaining > 0 and remaining < spire.segments.size() / 2, "a failing garden should sink the spire to its lowest terraces (%d of %d)" % [remaining, spire.segments.size()])
	spire.free()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL: ", message)
