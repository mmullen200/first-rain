extends SceneTree

# Flower colours show which patches the pollinator has connected (#49).

const EcologyGridModel = preload("res://ecology_grid.gd")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_native_colours_differ()
	_assert_creeping_mat_keeps_its_colour()
	_assert_seed_set_blends_the_parents()
	await _assert_linked_patches_converge_and_isolated_stays()
	if failed:
		quit(1)
	else:
		print("PASS: separate hollows start with different flower colours, creeping mats carry theirs, seeds blend the two parents, and the patches the pollinator links converge while an unreachable one keeps its colour")
		quit(0)


func _assert_native_colours_differ() -> void:
	var ecology = EcologyGridModel.new()
	var widest := 0.0
	var first: Vector2 = ecology.flower_hue[0]
	for hue in ecology.flower_hue:
		widest = maxf(widest, rad_to_deg(absf(first.angle_to(hue))))
	_assert(widest > 90.0, "the basin should start with clearly different flower colours (widest %.0f°)" % widest)


func _assert_creeping_mat_keeps_its_colour() -> void:
	var ecology = EcologyGridModel.new()
	var parent := Vector2i(10, 10)
	var child := Vector2i(11, 10)
	ecology.flower_hue[_i(ecology, parent)] = Vector2.from_angle(deg_to_rad(40.0))
	ecology.flower_hue[_i(ecology, child)] = Vector2.from_angle(deg_to_rad(200.0))
	ecology.rhizome[_i(ecology, parent)] = 0.8
	var next: PackedFloat32Array = ecology.rhizome.duplicate()
	next[_i(ecology, child)] = 0.05
	var pull := PackedFloat32Array()
	pull.resize(ecology.WIDTH * ecology.HEIGHT)
	pull[_i(ecology, child)] = 1.0
	ecology._mix_flower_lineages(next, pull)
	_assert(_degrees(ecology, child) < 45.0 and _degrees(ecology, child) > 35.0, "mat creeping into a cell should bring its colour (%.0f°)" % _degrees(ecology, child))


func _assert_seed_set_blends_the_parents() -> void:
	var ecology = EcologyGridModel.new()
	var mother := Vector2i(10, 10)
	var father := Vector2i(14, 10)
	for cell in [mother, father]:
		var i := _i(ecology, cell)
		ecology.rhizome[i] = 0.6
		ecology.ground_bloom[i] = 0.4
	for y in range(9, 12):
		for x in range(9, 12):
			var i := _i(ecology, Vector2i(x, y))
			ecology.moisture[i] = 0.5
			ecology.nutrients[i] = 0.3
			ecology.toxicity[i] = 0.0
			ecology.temperature[i] = 0.35
	ecology.flower_hue[_i(ecology, mother)] = Vector2.from_angle(deg_to_rad(40.0))
	ecology.flower_hue[_i(ecology, father)] = Vector2.from_angle(deg_to_rad(120.0))
	_assert(ecology.receive_pollen(mother, father, "rhizome", 0.04) > 0.0, "the mother patch should accept pollen")
	# The batch matures and plants its seedling on the 90th step.
	for ignored in 90:
		ecology._step_reproduction()
	var shifted := _degrees(ecology, mother)
	_assert(shifted > 45.0 and shifted < 80.0, "setting seed should shift the mother patch toward its pollen donor (%.0f°)" % shifted)
	var seedling_found := false
	for event in ecology.seed_events:
		if String(event["taxonomy"]) == "ecology.seedling_established":
			seedling_found = true
			var hue := _degrees(ecology, event["cell"])
			_assert(hue > 55.0 and hue < 90.0, "a seedling should carry a colour between its parents (%.0f°)" % hue)
	_assert(seedling_found, "a seedling should establish beside the mother patch")


func _assert_linked_patches_converge_and_isolated_stays() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene._seed_flower_lineage_fixture()
	var gold := Vector2i(14, 10)
	var violet := Vector2i(16, 10)
	var blue := Vector2i(29, 17)
	var gap_before := _gap(scene.ecology, gold, violet)
	var blue_before := _degrees(scene.ecology, blue)
	for ignored in 1200:
		scene._update_ecology_grid(scene.ECOLOGY_STEP_SECONDS)
	var gap_after := _gap(scene.ecology, gold, violet)
	_assert(gap_after < gap_before - 25.0, "patches the pollinator travels between should draw together (%.0f° apart, was %.0f°)" % [gap_after, gap_before])
	_assert(absf(_degrees(scene.ecology, blue) - blue_before) < 2.0, "a patch beyond the pollinator's reach should keep its colour")
	scene.queue_free()


func _gap(ecology, a: Vector2i, b: Vector2i) -> float:
	return rad_to_deg(absf(ecology.flower_hue[_i(ecology, a)].angle_to(ecology.flower_hue[_i(ecology, b)])))


func _degrees(ecology, cell: Vector2i) -> float:
	return fposmod(rad_to_deg(ecology.flower_hue[_i(ecology, cell)].angle()), 360.0)


func _i(ecology, cell: Vector2i) -> int:
	return cell.y * ecology.WIDTH + cell.x


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL: ", message)
