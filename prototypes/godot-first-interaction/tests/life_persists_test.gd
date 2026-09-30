extends SceneTree

const EcologyGridModel = preload("res://ecology_grid.gd")

var failed := false


func _initialize() -> void:
	var cell := Vector2i(30, 8)
	var persisting := _parched_patch(cell, true)
	var dying := _parched_patch(cell, false)
	var index: int = cell.y * EcologyGridModel.WIDTH + cell.x
	for _step in range(400):
		persisting.step()
		dying.step()
	_expect(dying.moss[index] < 0.05, "with the setting off, dry hot ground should kill the moss; moss=%.3f" % dying.moss[index])
	for layer in ["moss", "fungus", "rhizome"]:
		var amount: float = persisting.get(layer)[index]
		_expect(amount >= EcologyGridModel.LIFE_FLOOR - 0.0001, "with life persisting, %s should thin no lower than the floor; %s=%.3f" % [layer, layer, amount])
	_expect(persisting.moss[index] < 0.6, "life persisting should still let a patch thin; moss=%.3f" % persisting.moss[index])

	var faint := _parched_patch(cell, true)
	faint.moss[index] = 0.05
	for _step in range(200):
		faint.step()
	_expect(faint.moss[index] >= 0.05 - 0.0001, "a patch below the floor should keep what it has; moss=%.3f" % faint.moss[index])

	var dusted := _parched_patch(cell, true)
	for _front in range(30):
		dusted.apply_dust_front(cell.x)
	_expect(dusted.moss[index] >= EcologyGridModel.LIFE_FLOOR - 0.0001, "dust fronts should not strip moss below the floor; moss=%.3f" % dusted.moss[index])

	if not failed:
		print("PASS: while life persists, drying, heat and dust thin living layers but never below the floor")
	quit(1 if failed else 0)


func _parched_patch(cell: Vector2i, persists: bool) -> EcologyGridModel:
	var grid := EcologyGridModel.new()
	grid.life_persists = persists
	var index: int = cell.y * EcologyGridModel.WIDTH + cell.x
	grid.moss[index] = 0.6
	grid.fungus[index] = 0.5
	grid.rhizome[index] = 0.5
	grid.moisture[index] = 0.0
	grid.temperature[index] = 0.9
	return grid


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("FAIL: " + message)
