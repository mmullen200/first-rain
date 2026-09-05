extends SceneTree

const EcologyGrid = preload("res://ecology_grid.gd")
const AnimalSimulation = preload("res://animal_simulation.gd")

# Hold plant growth/weather fixed to isolate worker discovery and depletion.
class ForagingFixture extends EcologyGrid:
	func step() -> void:
		tick += 1

var failed := false

func _init() -> void:
	for fixture_seed in [1, 41, 73]:
		_run_foraging(fixture_seed)
	if failed:
		quit(1)
	else:
		print("PASS: local exploration, recruitment, depletion, scent decay, conserved transport, recall and worker/scent replay across three seeds")
		quit(0)

func _run_foraging(fixture_seed: int) -> void:
	var ecology = ForagingFixture.new()
	for y in range(ecology.HEIGHT):
		for x in range(ecology.WIDTH):
			var cell := Vector2i(x, y)
			for resource in ["moss", "rhizome", "dead_biomass", "toxicity"]:
				ecology.consume_resource(cell, resource, 100.0)
	var simulation = AnimalSimulation.new(ecology, fixture_seed)
	var home := Vector2i(8, 8)
	simulation.register_agent("colony", "colony:1", {"cell": home})
	for ignored in range(60):
		simulation.step()
	var colony: Dictionary = simulation.agent_state("colony:1")
	var occupied := {}
	for worker in colony["workers"]:
		occupied[worker["cell"]] = true
	_assert(occupied.size() > 6, "workers must independently explore without food")
	_assert(colony["pheromones"].is_empty(), "unsuccessful exploration must not manufacture food trails")
	var food := home + Vector2i(4, 0)
	ecology.add_resources(food, {"rhizome": 0.3})
	var replay_checked := false
	for ignored in range(1100):
		simulation.step()
		colony = simulation.agent_state("colony:1")
		if not replay_checked and not colony["pheromones"].is_empty():
			var snapshot: Dictionary = simulation.snapshot()
			var replay = AnimalSimulation.new(ForagingFixture.new(), 999)
			_assert(replay.restore(snapshot), "in-flight colony snapshot must restore")
			for replay_tick in range(40):
				simulation.step()
				replay.step()
			_assert(replay.snapshot() == simulation.snapshot(), "workers, paths, scent and events must replay exactly")
			replay_checked = true
	_assert(replay_checked, "successful return must produce a scent field")
	var gatherers := {}
	var gathered := 0.0
	var returned := 0.0
	var recruited := 0
	for event in simulation.event_history:
		var facts: Dictionary = event["facts"]
		match event["taxonomy"]:
			"organism.colony_plant_gathered":
				gatherers[facts["worker_id"]] = true
				gathered += float(facts["amount"])
				if bool(facts["followed_trail"]):
					recruited += 1
			"organism.colony_plant_returned":
				returned += float(facts["amount"])
	_assert(gatherers.size() > 3 and recruited > 3, "several recruited workers must reach and gather food")
	_assert(ecology.resource_amount(food, "rhizome") < AnimalSimulation.COLONY_LOAD, "workers must exhaust the finite food source")
	var carrying := 0.0
	for worker in simulation.agent_state("colony:1")["workers"]:
		carrying += float(worker["load"])
	_assert(is_equal_approx(gathered, returned + carrying), "every gathered load must be carried or delivered")
	_assert(is_equal_approx(0.3, gathered + ecology.resource_amount(food, "rhizome")), "food removal must equal worker collection")
	for ignored in range(400):
		simulation.step()
	_assert(simulation.agent_state("colony:1")["pheromones"].is_empty(), "depleted food trails must fade completely without reinforcement")
	_assert(not simulation.recall_colony("colony:1", true), "scattered workers should need time to return")
	for ignored in range(120):
		simulation.step()
	_assert(simulation.recall_colony("colony:1", true), "recall must terminate once all workers and loads are home")
	_assert(simulation.set_agent_presence("colony:1", false), "recalled colony must depart")
	var departed: Dictionary = simulation.agent_state("colony:1")
	for ignored in range(10):
		simulation.step()
	_assert(simulation.agent_state("colony:1") == departed, "absent workers must not keep foraging")
	var new_home := Vector2i(14, 8)
	simulation.set_agent_presence("colony:1", true, new_home)
	colony = simulation.agent_state("colony:1")
	_assert(colony["pheromones"].is_empty(), "return must not inherit trails around an old nest")
	for worker in colony["workers"]:
		_assert(worker["cell"] == new_home and worker["path"] == [new_home], "return must reset every worker route to the current nest")
	_assert(simulation.conservation_violations.is_empty(), "worker transfers must conserve material")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		failed = true
