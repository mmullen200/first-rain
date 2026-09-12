extends SceneTree

const EcologyGrid = preload("res://ecology_grid.gd")
var failed := false


func _initialize() -> void:
	var ecology = EcologyGrid.new()
	_assert(EcologyGrid.WIDTH == 48 and EcologyGrid.HEIGHT == 32, "Four Bowls should contain 48 × 32 Ecological Cells")
	_assert(is_equal_approx(ecology.terrain_height(EcologyGrid.HEADWALL_SPRING_CELL), 13.2), "Headwall spring spot height should be 13.2 m")
	_assert(is_equal_approx(ecology.terrain_height(EcologyGrid.TOXIC_VENT_CELL), 11.3), "Toxic Vent spot height should be 11.3 m")
	_assert(is_equal_approx(ecology.terrain_height(EcologyGrid.DRY_TERRACE_CELL), 10.5), "Dry Terrace spot height should be 10.5 m")
	_assert(is_equal_approx(ecology.terrain_height(EcologyGrid.DIVIDE_CELL), 9.5), "Divide spot height should be 9.5 m")
	_assert(is_equal_approx(ecology.terrain_height(EcologyGrid.WRECK_CELL), 6.9), "wreck flank spot height should be 6.9 m")
	_assert(is_equal_approx(ecology.terrain_height(EcologyGrid.SHELTER_BOWL_CELL), 5.4), "Shelter Bowl spot height should be 5.4 m")
	_assert(is_equal_approx(ecology.terrain_height(EcologyGrid.LONG_MEADOW_CELL), 3.8), "Long Meadow spot height should be 3.8 m")
	_assert(is_equal_approx(ecology.terrain_height(EcologyGrid.SOUTH_SHELF_CELL), 5.6), "South Shelf spot height should be 5.6 m")
	_assert(is_equal_approx(ecology.terrain_height(EcologyGrid.NECK_CELL), 2.3), "Neck spot height should be 2.3 m")
	_assert(is_equal_approx(ecology.terrain_height(EcologyGrid.SINK_CELL), 0.6), "Sink spot height should be 0.6 m")

	var spring_path := ecology.flow_path(EcologyGrid.HEADWALL_SPRING_CELL)
	var fork_path := ecology.flow_path(EcologyGrid.FORK_CELL)
	var lows: Array[Vector2i] = []
	for y in range(EcologyGrid.HEIGHT):
		for x in range(EcologyGrid.WIDTH):
			var cell := Vector2i(x, y)
			if ecology.downhill_neighbor(cell) == cell:
				lows.append(cell)
	_assert(spring_path.has(EcologyGrid.FORK_CELL), "the dry gully should descend from the Headwall to the Fork")
	_assert(fork_path.has(EcologyGrid.CHANNEL_CELL) and fork_path.has(EcologyGrid.SINK_CELL), "the uncut Fork should send water east through the live watercourse to the Sink")
	_assert(not fork_path.has(EcologyGrid.SHELTER_BOWL_CELL), "the uncut Fork should keep water out of the Shelter Bowl")
	_assert(lows == [EcologyGrid.SHELTER_BOWL_CELL, EcologyGrid.SOUTH_SHELF_CELL, EcologyGrid.SINK_CELL], "only the three closed bowls should retain water away from the leaking Long Meadow")
	_assert(ecology.downhill_neighbor(Vector2i(0, 0)) == EcologyGrid.OUT_OF_BASIN, "a stranded boundary cell should drain out of the Crash Basin")
	var edge_index := EcologyGrid.WIDTH - 1
	ecology.surface_water[edge_index] = 0.5
	ecology.step()
	_assert(ecology.surface_water[edge_index] < 0.05, "water stranded on a boundary should leave the Crash Basin")

	for _cut in range(6):
		ecology.excavate(EcologyGrid.DIG_TEST_CELL, 0.22)
	var diverted_path := ecology.flow_path(EcologyGrid.FORK_CELL)
	_assert(diverted_path.has(EcologyGrid.DIG_TEST_CELL), "six shallow G cuts should breach the 1.3 m south lip at the Fork")

	if failed:
		quit(1)
	else:
		print("PASS: Four Bowls dimensions, surveyed spot heights and edge drainage match rev B")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL: ", message)
