extends SceneTree

const EcologyGrid = preload("res://ecology_grid.gd")


func _initialize() -> void:
	# Pour on the sloping flank where the Astronaut starts.
	var source: Vector2i = EcologyGrid.WRECK_CELL
	var neighbours: Array[Vector2i] = []
	for y in range(source.y - 2, source.y + 3):
		for x in range(source.x - 2, source.x + 3):
			if Vector2i(x, y) != source:
				neighbours.append(Vector2i(x, y))

	# The old even disc wets uphill ground too; this is the reported bug.
	var disc = EcologyGrid.new()
	var disc_before := _fields(disc)
	disc.add_water(disc.world_position(source.x, source.y))
	var disc_uphill_wetted := 0
	for cell in neighbours:
		if _uphill(disc, source, cell) and _gain(disc, disc_before, cell) > 0.0:
			disc_uphill_wetted += 1
	if disc_uphill_wetted == 0:
		_fail("the test site has no uphill neighbours to check against")
		return

	var ecology = EcologyGrid.new()
	var before := _fields(ecology)
	ecology.pour_water(ecology.world_position(source.x, source.y))
	for cell in neighbours:
		if _uphill(ecology, source, cell) and _gain(ecology, before, cell) > 0.0:
			_fail("pouring wetted uphill cell %s" % cell)
			return
	var downhill: Vector2i = ecology.downhill_neighbor(source)
	if ecology.resource_amount(downhill, "surface_water") <= float(before["surface"][downhill]):
		_fail("pouring sent no surface water to the downhill neighbour %s" % downhill)
		return

	# As the ecology steps, the poured water keeps moving downhill.
	var start_height := _mean_water_height(ecology, before, source)
	for i in range(3):
		ecology.step()
	if _mean_water_height(ecology, before, source) >= start_height:
		_fail("poured surface water did not move downhill as the ecology stepped")
		return
	print("PASS: a pour soaks only level and downhill ground and its water runs away downhill (the old disc wetted %d uphill cells)" % disc_uphill_wetted)
	quit(0)


func _uphill(ecology, source: Vector2i, cell: Vector2i) -> bool:
	return ecology.hydraulic_height(cell) > ecology.hydraulic_height(source) + 0.02


func _fields(ecology) -> Dictionary:
	var moisture := {}
	var surface := {}
	for y in range(ecology.HEIGHT):
		for x in range(ecology.WIDTH):
			var cell := Vector2i(x, y)
			moisture[cell] = ecology.cell_snapshot(x, y)["moisture"]
			surface[cell] = ecology.resource_amount(cell, "surface_water")
	return {"moisture": moisture, "surface": surface}


func _gain(ecology, before: Dictionary, cell: Vector2i) -> float:
	var moisture_gain: float = ecology.cell_snapshot(cell.x, cell.y)["moisture"] - float(before["moisture"][cell])
	var surface_gain: float = ecology.resource_amount(cell, "surface_water") - float(before["surface"][cell])
	return maxf(moisture_gain, surface_gain)


# Mean terrain height of the surface water the pour added near where it
# landed, weighted by how much each cell gained.
func _mean_water_height(ecology, before: Dictionary, source: Vector2i) -> float:
	var total := 0.0
	var weighted := 0.0
	for y in range(maxi(source.y - 8, 0), mini(source.y + 9, ecology.HEIGHT)):
		for x in range(maxi(source.x - 8, 0), mini(source.x + 9, ecology.WIDTH)):
			var water: float = maxf(0.0, ecology.resource_amount(Vector2i(x, y), "surface_water") - float(before["surface"][Vector2i(x, y)]))
			total += water
			weighted += water * ecology.terrain_height(Vector2i(x, y))
	return weighted / maxf(total, 0.0001)


func _fail(message: String) -> void:
	printerr("FAIL: " + message)
	quit(1)
