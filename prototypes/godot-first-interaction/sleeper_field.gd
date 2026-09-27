extends Node3D

# THROWAWAY PROTOTYPE.
# Sleeping animals. Nothing walks into the Crash Basin: grazers lie buried in
# stone-like shells, flying vectors wait as pupae in the soil, and wetland
# engineers lie curled in dried mud casings in the beds of old watercourses.
# Placement comes from a fixed seed, and each species only sleeps in ground
# that suits it. main.gd decides when a sleeper stirs, wakes, dies or sleeps
# again; this node owns only the places and the markers.
# The colony sleeps as queens in hoodoos (hoodoo_field.gd) and the predator
# drifts in the high air until a dust front brings it down (main.gd), so
# neither has a sleeper here.

const EcologyGridModel = preload("res://ecology_grid.gd")

const PLACEMENT_SEED := 20260927
const COUNTS := {"grazer": 6, "vector": 5, "wetland_engineer": 4}
const SPACING_CELLS := 4
const PARTNER_DISTANCE := 2
const WRECK_CLEARANCE_CELLS := 3
const HOODOO_CLEARANCE_CELLS := 1
const MAX_START_TOXICITY := 0.3
const STIR_LABELS := {
	"grazer": "STONE SHELL / STIRRING",
	"vector": "PUPAE / STIRRING",
	"wetland_engineer": "MUD CASING / STIRRING"
}

# Each entry: {"species": String, "cell": Vector2i}. main.gd moves the cell
# when an animal goes back to sleep somewhere new.
var sleepers: Array[Dictionary] = []
var _markers: Array[Node3D] = []
var _stir_time := 0.0


func _init() -> void:
	name = "Sleepers"


# `spine_affinity` holds main.gd's drainage-spine measure per cell; engineers
# sleep only where water gathers when it returns.
func build(ecology, hoodoo_cells: Array[Vector2i], spine_affinity: PackedFloat32Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PLACEMENT_SEED
	# One of each kind always sleeps near the ground the opening leads to:
	# grazers and vectors around the Shelter Bowl, engineers on the channel
	# through Long Meadow. The rest are scattered.
	_place_nearest("grazer", EcologyGridModel.SHELTER_BOWL_CELL, ecology, hoodoo_cells, spine_affinity)
	_place_partner(sleepers.back()["cell"], ecology, hoodoo_cells, spine_affinity)
	_place_nearest("vector", EcologyGridModel.SHELTER_BOWL_CELL, ecology, hoodoo_cells, spine_affinity)
	_place_nearest("wetland_engineer", EcologyGridModel.CHANNEL_CELL, ecology, hoodoo_cells, spine_affinity)
	for species in COUNTS:
		var candidates: Array[Vector2i] = []
		for y in range(1, EcologyGridModel.HEIGHT - 1):
			for x in range(1, EcologyGridModel.WIDTH - 1):
				var cell := Vector2i(x, y)
				if _fits(species, cell, ecology, hoodoo_cells, spine_affinity):
					candidates.append(cell)
		var attempts := 0
		while _count(species) < int(COUNTS[species]) and attempts < 400 and not candidates.is_empty():
			attempts += 1
			var cell: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
			if _far_from_sleepers(cell):
				_add_sleeper(species, cell, ecology, rng)
				if species == "grazer":
					_place_partner(cell, ecology, hoodoo_cells, spine_affinity)


# For an animal that goes to sleep with no sleeper of its own (one placed
# awake by a fixture). Returns its index.
func add_sleeper(species: String, cell: Vector2i, ecology) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = PLACEMENT_SEED + sleepers.size()
	_add_sleeper(species, cell, ecology, rng)
	return sleepers.size() - 1


func cells_for(species: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for sleeper in sleepers:
		if String(sleeper["species"]) == species:
			cells.append(sleeper["cell"])
	return cells


func index_at(cell: Vector2i) -> int:
	for index in range(sleepers.size()):
		if sleepers[index]["cell"] == cell:
			return index
	return -1


# dormant: the marker lies still. stirring: it rocks and a label says so.
# awake: the marker is gone, the animal walks. dead: a pale, flattened husk.
func show_state(index: int, state: String, ecology) -> void:
	var marker: Node3D = _markers[index]
	var cell: Vector2i = sleepers[index]["cell"]
	var world: Vector2 = ecology.world_position(cell.x, cell.y)
	marker.position = Vector3(world.x, ecology.terrain_height(cell), world.y)
	marker.visible = state != "awake"
	var body: Node3D = marker.get_node("Body")
	var label: Label3D = marker.get_node("Label")
	label.visible = state == "stirring"
	body.rotation = Vector3.ZERO
	marker.set_meta("state", state)
	if state == "dead":
		body.scale = Vector3(1.0, 0.45, 1.0)
		for part in body.get_children():
			(part as MeshInstance3D).material_override = _material(Color("a39d8e"), 0.95)
	elif marker.has_meta("living_scale"):
		body.scale = marker.get_meta("living_scale")


func animate(delta: float) -> void:
	_stir_time += delta
	for marker in _markers:
		if not marker.visible or String(marker.get_meta("state", "dormant")) != "stirring":
			continue
		var body: Node3D = marker.get_node("Body")
		body.rotation.z = sin(_stir_time * 7.0) * 0.12
		body.rotation.x = sin(_stir_time * 5.3 + 1.0) * 0.07


func marker(index: int) -> Node3D:
	return _markers[index]


func _place_nearest(species: String, target: Vector2i, ecology, hoodoo_cells: Array[Vector2i], spine_affinity: PackedFloat32Array) -> void:
	var best := Vector2i(-1, -1)
	var best_distance := 1 << 30
	for y in range(1, EcologyGridModel.HEIGHT - 1):
		for x in range(1, EcologyGridModel.WIDTH - 1):
			var cell := Vector2i(x, y)
			var distance := (cell - target).length_squared()
			if distance < best_distance and _fits(species, cell, ecology, hoodoo_cells, spine_affinity) and _far_from_sleepers(cell):
				best = cell
				best_distance = distance
	if best.x >= 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = PLACEMENT_SEED + sleepers.size()
		_add_sleeper(species, best, ecology, rng)


# Grazers sleep in pairs, a couple of cells apart, so one patch of forage can
# wake a small herd; a predator only comes down where two grazers live.
func _place_partner(cell: Vector2i, ecology, hoodoo_cells: Array[Vector2i], spine_affinity: PackedFloat32Array) -> void:
	var best := Vector2i(-1, -1)
	var best_distance := 1 << 30
	for y in range(cell.y - PARTNER_DISTANCE, cell.y + PARTNER_DISTANCE + 1):
		for x in range(cell.x - PARTNER_DISTANCE, cell.x + PARTNER_DISTANCE + 1):
			var candidate := Vector2i(x, y)
			if x < 1 or y < 1 or x >= EcologyGridModel.WIDTH - 1 or y >= EcologyGridModel.HEIGHT - 1:
				continue
			var distance := (candidate - cell).length_squared()
			if _distance(candidate, cell) != PARTNER_DISTANCE or distance >= best_distance:
				continue
			if not _fits("grazer", candidate, ecology, hoodoo_cells, spine_affinity) or not _far_from_sleepers(candidate, cell):
				continue
			best = candidate
			best_distance = distance
	if best.x >= 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = PLACEMENT_SEED + sleepers.size()
		_add_sleeper("grazer", best, ecology, rng)


func _fits(species: String, cell: Vector2i, ecology, hoodoo_cells: Array[Vector2i], spine_affinity: PackedFloat32Array) -> bool:
	if _distance(cell, EcologyGridModel.WRECK_CELL) < WRECK_CLEARANCE_CELLS:
		return false
	for hoodoo in hoodoo_cells:
		if _distance(cell, hoodoo) <= HOODOO_CLEARANCE_CELLS:
			return false
	var index: int = cell.y * EcologyGridModel.WIDTH + cell.x
	if ecology.toxicity[index] > MAX_START_TOXICITY:
		return false
	var holds_water: bool = ecology.downhill_neighbor(cell) == cell
	var on_spine := spine_affinity[index] > 0.0
	match species:
		"wetland_engineer":
			return on_spine
		"grazer":
			return not holds_water and not on_spine
		"vector":
			return not holds_water
	return false


# `partner` is exempt: a grazer's partner sleeps closer than the spacing.
func _far_from_sleepers(cell: Vector2i, partner := Vector2i(-1, -1)) -> bool:
	for sleeper in sleepers:
		if sleeper["cell"] != partner and _distance(cell, sleeper["cell"]) < SPACING_CELLS:
			return false
	return true


func _count(species: String) -> int:
	return cells_for(species).size()


func _distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _add_sleeper(species: String, cell: Vector2i, ecology, rng: RandomNumberGenerator) -> void:
	sleepers.append({"species": species, "cell": cell})
	var marker := Node3D.new()
	marker.name = "Sleeper_%s_%d_%d" % [species, cell.x, cell.y]
	var body := Node3D.new()
	body.name = "Body"
	body.rotation.y = rng.randf_range(0.0, TAU)
	marker.add_child(body)
	match species:
		"grazer":
			# A grey, stone-like hump half sunk in the ground.
			body.add_child(_ellipsoid(0.26, Vector3(1.35, 0.5, 0.9), Vector3(0.0, 0.04, 0.0), Color("65665f")))
			body.add_child(_ellipsoid(0.12, Vector3(1.0, 0.7, 0.9), Vector3(0.28, 0.03, 0.0), Color("5b5c56")))
		"vector":
			# A few pale pupal cases poking up through the soil.
			for pupa in range(3):
				var angle := TAU * float(pupa) / 3.0 + rng.randf_range(-0.4, 0.4)
				var pupa_case := _ellipsoid(0.055, Vector3(1.0, 2.2, 1.0), Vector3(cos(angle) * 0.14, 0.08, sin(angle) * 0.14), Color("d8c79a"))
				pupa_case.rotation = Vector3(rng.randf_range(-0.35, 0.35), 0.0, rng.randf_range(-0.35, 0.35))
				body.add_child(pupa_case)
		"wetland_engineer":
			# A dark, dried mud casing in the bed of an old watercourse.
			body.add_child(_ellipsoid(0.32, Vector3(1.25, 0.42, 1.0), Vector3(0.0, 0.03, 0.0), Color("5a4632")))
			body.add_child(_ellipsoid(0.18, Vector3(1.4, 0.3, 0.3), Vector3(0.0, 0.1, 0.0), Color("3e2f22")))
	marker.set_meta("living_scale", body.scale)
	var label := Label3D.new()
	label.name = "Label"
	label.text = String(STIR_LABELS[species])
	label.position.y = 0.7
	label.font_size = 25
	label.pixel_size = 0.0048
	label.modulate = Color("d9d2b8")
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.visible = false
	marker.add_child(label)
	var world: Vector2 = ecology.world_position(cell.x, cell.y)
	marker.position = Vector3(world.x, ecology.terrain_height(cell), world.y)
	add_child(marker)
	_markers.append(marker)


func _ellipsoid(radius: float, scale_value: Vector3, offset: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	part.mesh = mesh
	part.scale = scale_value
	part.position = offset
	part.material_override = _material(color, 0.94)
	return part


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result
