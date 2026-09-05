extends SceneTree

const EcologyGrid = preload("res://ecology_grid.gd")
const AnimalSimulation = preload("res://animal_simulation.gd")
var failed := false

class StillEcology extends EcologyGrid:
	func step() -> void:
		tick += 1

func _init() -> void:
	var ecology = StillEcology.new()
	var simulation = AnimalSimulation.new(ecology, 41)
	var home := Vector2i(8, 8)
	var food := Vector2i(11, 8)
	simulation.register_agent("colony", "colony:1", {"cell": home})
	for worker in simulation.agents["colony:1"]["workers"]:
		worker["cooldown"] = 10000
	var worker: Dictionary = simulation.agents["colony:1"]["workers"][0]
	worker["cell"] = food
	worker["previous_cell"] = food
	worker["path"] = [home, Vector2i(9, 9), Vector2i(10, 9), Vector2i(11, 9), Vector2i(12, 9), Vector2i(12, 8), food]
	worker["cooldown"] = 0
	ecology.add_resources(food, {"rhizome": 0.1})
	simulation.step()
	_assert(float(worker["load"]) > 0.0, "fixture worker must gather from the food patch")
	var previous := food
	for ignored in range(300):
		simulation.step()
		var current: Vector2i = worker["cell"]
		if current != previous:
			_assert(current.y == home.y and current.x < previous.x, "loaded worker detoured away from the direct food-to-nest line: %s -> %s" % [previous, current])
			previous = current
		if current == home:
			break
	_assert(worker["cell"] == home, "loaded worker must reach its nest")
	for scent_cell in simulation.agents["colony:1"]["pheromones"]:
		_assert(scent_cell.y == home.y and scent_cell.x >= home.x and scent_cell.x <= food.x, "successful return must mark the direct route, not the search detour")
	var cardinal_speed := _return_speed(Vector2i(1, 0))
	var diagonal_speed := _return_speed(Vector2i(1, 1))
	_assert(cardinal_speed <= 0.34 and diagonal_speed <= 0.34, "small workers should crawl at about 0.33 world units/second, measured %.3f / %.3f" % [cardinal_speed, diagonal_speed])
	_assert(absf(cardinal_speed - diagonal_speed) < 0.015, "diagonal travel must not be faster than cardinal travel")
	if failed:
		quit(1)
	else:
		print("PASS: loaded workers mark a direct nest route; cardinal/diagonal speeds %.3f / %.3f world units per second" % [cardinal_speed, diagonal_speed])
		quit(0)

func _return_speed(offset: Vector2i) -> float:
	var simulation = AnimalSimulation.new(StillEcology.new(), 41)
	var home := Vector2i(8, 8)
	simulation.register_agent("colony", "colony:1", {"cell": home})
	var worker: Dictionary = simulation.agents["colony:1"]["workers"][0]
	worker["cell"] = home + offset
	worker["previous_cell"] = worker["cell"]
	worker["path"] = [home, worker["cell"]]
	worker["phase"] = "returning"
	worker["load"] = 0.003
	worker["cooldown"] = 0
	simulation.step()
	return Vector2(offset).length() * EcologyGrid.CELL_SIZE / (float(int(worker["cooldown"]) + 1) * 0.34)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		failed = true
