extends SceneTree

const EcologyGridModel = preload("res://ecology_grid.gd")
var failed := false


func _initialize() -> void:
	var ecology = EcologyGridModel.new()
	if not ecology.has_method("terrain_height") or not ecology.has_method("downhill_neighbor"):
		_fail("Ecological Cells do not expose terrain height and lowest-neighbour drainage")
		return

	var low := INF
	var high := -INF
	for y in range(EcologyGridModel.HEIGHT):
		for x in range(EcologyGridModel.WIDTH):
			var elevation: float = ecology.terrain_height(Vector2i(x, y))
			low = minf(low, elevation)
			high = maxf(high, elevation)
	_assert(high - low >= 1.5 and high - low <= 2.5, "terrain relief should read as a deliberate 1.5–2.5 world-unit shape")

	var catchment: Vector2i = EcologyGridModel.HIGH_CATCHMENT_CELL
	var hollow: Vector2i = EcologyGridModel.CLOSED_HOLLOW_CELL
	var terrace: Vector2i = EcologyGridModel.DRY_TERRACE_CELL
	_assert(ecology.terrain_height(catchment) > ecology.terrain_height(hollow), "the catchment should stand above the closed hollow")
	_assert(ecology.downhill_neighbor(hollow) == hollow, "the closed hollow should have no lower outlet")
	_assert(not ecology.flow_path(catchment).has(terrace), "the dry terrace should sit outside the catchment's natural flow path")
	_assert(ecology.flow_path(catchment).has(EcologyGridModel.CHANNEL_CELL), "catchment runoff should converge into the Drainage Spine")
	_assert(ecology.flow_path(catchment).has(hollow), "the Drainage Spine should feed the closed hollow")
	var terrace_water_before: float = ecology.surface_water[terrace.y * EcologyGridModel.WIDTH + terrace.x]
	ecology.add_water(ecology.world_position(catchment.x, catchment.y), 0.9, 0.5)
	for _tick in range(60):
		ecology.step()
	_assert(ecology.surface_water[hollow.y * EcologyGridModel.WIDTH + hollow.x] > terrace_water_before + 0.02, "a visible Drainage Pulse poured high should arrive and remain in the closed hollow")

	var upstream: Vector2i = EcologyGridModel.DAM_TEST_UPSTREAM_CELL
	var original_route: Vector2i = ecology.downhill_neighbor(upstream)
	ecology.dam_material[original_route.y * EcologyGridModel.WIDTH + original_route.x] = 1.0
	_assert(ecology.downhill_neighbor(upstream) != original_route, "dam material should divert incoming flow to the next-lowest neighbour")

	var dig_target: Vector2i = EcologyGridModel.DIG_TEST_CELL
	var before: float = ecology.terrain_height(dig_target)
	ecology.excavate(dig_target, 0.25)
	_assert(is_equal_approx(ecology.terrain_height(dig_target), before - 0.25), "excavation should persistently lower one Ecological Cell")

	var vent: Vector2i = EcologyGridModel.TOXIC_VENT_CELL
	var downstream: Vector2i = ecology.downhill_neighbor(vent)
	var downstream_index: int = downstream.y * EcologyGridModel.WIDTH + downstream.x
	var toxicity_before: float = ecology.toxicity[downstream_index]
	ecology.moisture[vent.y * EcologyGridModel.WIDTH + vent.x] = 1.0
	ecology.step()
	_assert(ecology.toxicity[downstream_index] > toxicity_before, "runoff from the upstream vent should carry toxicity downstream")

	if failed:
		quit(1)
	else:
		print("PASS: visible terrain topology drives converging water, closed-hollow retention, diversion, excavation, and toxic runoff")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failed = true
	printerr("FAIL: ", message)
