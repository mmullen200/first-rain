extends Node3D

# THROWAWAY PROTOTYPE.
# Hoodoos: standing spires of the previous biosphere's undecayed remains, and
# the same material that seals the Headwall spring. They are objects standing
# on Ecological Cells, not terrain, so the height field and drainage are
# untouched and a spire can later be removed piece by piece. Placement and
# shapes come from a fixed seed, so every run builds the same field.
# Some hoodoos hold a sleeping eusocial queen in a sealed chamber at the base;
# main.gd decides when one wakes.
# Each hoodoo holds old matter in the ecology grid, in proportion to its
# height. Nothing rots it; colony workers break it off, and sync() shrinks the
# spire to match what is left. The spring spire's matter is the ecology's own
# spring seal.

const EcologyGridModel = preload("res://ecology_grid.gd")

const PLACEMENT_SEED := 20260923
const CLUSTER_COUNT := 9
const CLUSTER_SPACING_CELLS := 7.0
const HOODOO_SPACING_CELLS := 1.6
const WRECK_CLEARANCE_CELLS := 6.0
const LANDMARK_CLEARANCE_CELLS := 2.5
const BOWL_CLEARANCE_CELLS := 4.0
const WATERCOURSE_CLEARANCE_CELLS := 1.5
const BASE_SINK := 0.45
const RING_SEGMENTS := 22
const QUEEN_SEED := 20260924
const QUEEN_CHANCE := 0.7
const MIN_QUEENS := 4
# Horizontal direction from a hoodoo toward the gameplay camera (main.gd offset).
const CAMERA_SIDE := Vector2(8.8, 10.5)
const MATTER_PER_METRE := 0.1
# Below this share of its matter a hoodoo has lost its cap.
const CAP_LOST_FRACTION := 0.7
# What still stands of an ordinary hoodoo once it is eaten down.
const STUB_FRACTION := 0.12

const HOODOO_SHADER := """
shader_type spatial;
render_mode cull_back;

varying vec3 world_position;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Horizontal bedding bands that wander slightly, like the reference spires.
	float wander = sin(world_position.x * 1.3 + world_position.z * 0.9) * 0.35;
	float band = sin(world_position.y * 5.2 + wander * 3.0) * 0.5 + 0.5;
	float fine = hash(floor(world_position * 7.0));
	vec3 color = COLOR.rgb * mix(0.7, 1.1, band) * mix(0.93, 1.05, fine);
	ALBEDO = color;
	ROUGHNESS = 0.94;
}
"""

var hoodoo_cells: Array[Vector2i] = []
var hoodoo_heights: Dictionary = {}
var hoodoo_widths: Dictionary = {}
var queen_cells: Array[Vector2i] = []
var full_matter: Dictionary = {}
var remaining_fractions: Dictionary = {}
var material: ShaderMaterial


func _init() -> void:
	name = "Hoodoos"
	var shader := Shader.new()
	shader.code = HOODOO_SHADER
	material = ShaderMaterial.new()
	material.shader = shader


func build(ecology) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PLACEMENT_SEED

	# The seal over the spring is the tallest spire on the map.
	_add_hoodoo(ecology, EcologyGridModel.HEADWALL_SPRING_CELL, rng, {"height": 6.8, "width": 1.25, "capped": true})

	var watercourse: Array[Vector2i] = ecology.flow_path(EcologyGridModel.HEADWALL_SPRING_CELL)
	var candidates: Array[Vector2i] = []
	for y in range(2, EcologyGridModel.HEIGHT - 2):
		for x in range(2, EcologyGridModel.WIDTH - 2):
			var cell := Vector2i(x, y)
			if _is_clear_ground(ecology, cell, watercourse):
				candidates.append(cell)

	# Hoodoos stand in small groups, as they weather out of one old layer.
	var centres: Array[Vector2i] = []
	var attempts := 0
	while centres.size() < CLUSTER_COUNT and attempts < 400 and not candidates.is_empty():
		attempts += 1
		var centre: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		if _far_from(centre, centres, CLUSTER_SPACING_CELLS) and _far_from(centre, hoodoo_cells, CLUSTER_SPACING_CELLS):
			centres.append(centre)

	var group_founders: Array[Vector2i] = []
	for centre in centres:
		var group_size := rng.randi_range(1, 3)
		var placed := 0
		var tries := 0
		while placed < group_size and tries < 24:
			tries += 1
			var cell := centre if placed == 0 else centre + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
			if not candidates.has(cell) or not _far_from(cell, hoodoo_cells, HOODOO_SPACING_CELLS):
				continue
			var height := rng.randf_range(2.3, 4.4)
			_add_hoodoo(ecology, cell, rng, {
				"height": height,
				"width": rng.randf_range(0.72, 1.0) * clampf(height / 3.4, 0.85, 1.15),
				"capped": rng.randf() < 0.68,
			})
			if placed == 0:
				group_founders.append(cell)
			placed += 1
	_choose_queens(group_founders)
	for cell in hoodoo_cells:
		if cell != EcologyGridModel.HEADWALL_SPRING_CELL:
			ecology.add_resources(cell, {"old_matter": float(hoodoo_heights[cell]) * MATTER_PER_METRE})
		full_matter[cell] = ecology.resource_amount(cell, "old_matter")
		remaining_fractions[cell] = 1.0


# Match every spire to the old matter the colony has left in its cell. The
# column shortens and narrows a little, the cap drops away early, and an
# ordinary hoodoo ends as a low stub. The spring spire goes entirely.
func sync(ecology) -> void:
	for cell in hoodoo_cells:
		var full: float = full_matter[cell]
		var fraction := clampf(ecology.resource_amount(cell, "old_matter") / full, 0.0, 1.0) if full > 0.0 else 0.0
		if is_equal_approx(fraction, float(remaining_fractions[cell])):
			continue
		remaining_fractions[cell] = fraction
		var body: StaticBody3D = get_node("Hoodoo_%d_%d" % [cell.x, cell.y])
		var mass: Node3D = body.get_node("Mass")
		var gone := fraction <= 0.0 and cell == EcologyGridModel.HEADWALL_SPRING_CELL
		var standing := lerpf(STUB_FRACTION, 1.0, fraction)
		mass.visible = not gone
		mass.scale = Vector3(lerpf(0.8, 1.0, fraction), standing, lerpf(0.8, 1.0, fraction))
		if mass.has_node("Cap"):
			mass.get_node("Cap").visible = fraction >= CAP_LOST_FRACTION
		var collision: CollisionShape3D = body.get_node("Collision")
		collision.disabled = gone
		var cylinder: CylinderShape3D = collision.shape
		cylinder.height = (float(hoodoo_heights[cell]) + BASE_SINK) * standing
		collision.position.y = cylinder.height * 0.5


# At most one sleeping queen per group, so wherever the player works there is
# usually one nearby, but not every group has one. A separate seed keeps the
# hoodoo shapes unchanged.
func _choose_queens(group_founders: Array[Vector2i]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = QUEEN_SEED
	var passed_over: Array[Vector2i] = []
	for cell in group_founders:
		if rng.randf() < QUEEN_CHANCE:
			queen_cells.append(cell)
		else:
			passed_over.append(cell)
	while queen_cells.size() < MIN_QUEENS and not passed_over.is_empty():
		queen_cells.append(passed_over.pop_front())
	for cell in queen_cells:
		_add_sealed_chamber(cell, rng)


# A low, dark, rounded plug at the foot of the spire: the one outward sign
# that something is sealed inside.
func _add_sealed_chamber(cell: Vector2i, rng: RandomNumberGenerator) -> void:
	var body: Node3D = get_node("Hoodoo_%d_%d" % [cell.x, cell.y])
	var width: float = hoodoo_widths[cell]
	# Face the chamber roughly toward the fixed camera so it is never hidden
	# behind its own spire.
	var world_angle := atan2(CAMERA_SIDE.y, CAMERA_SIDE.x) + rng.randf_range(-0.6, 0.6)
	var local_direction: Vector3 = body.transform.basis.inverse() * Vector3(cos(world_angle), 0.0, sin(world_angle))
	var angle := atan2(local_direction.z, local_direction.x)
	var plug := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.27
	mesh.height = 0.54
	plug.mesh = mesh
	var plug_material := StandardMaterial3D.new()
	plug_material.albedo_color = Color("3d2418")
	plug_material.roughness = 0.97
	plug.material_override = plug_material
	var reach := width * 0.72
	plug.position = Vector3(cos(angle) * reach, BASE_SINK + 0.16, sin(angle) * reach)
	plug.rotation.y = -angle
	plug.scale = Vector3(0.55, 0.8, 1.0)
	plug.name = "SealedChamber"
	body.add_child(plug)


func _is_clear_ground(ecology, cell: Vector2i, watercourse: Array[Vector2i]) -> bool:
	if _cell_distance(cell, EcologyGridModel.WRECK_CELL) < WRECK_CLEARANCE_CELLS:
		return false
	for landmark in [EcologyGridModel.TOXIC_VENT_CELL, EcologyGridModel.DRY_TERRACE_CELL, EcologyGridModel.FORK_CELL, EcologyGridModel.CHANNEL_CELL, EcologyGridModel.DIVIDE_CELL, EcologyGridModel.SOUTH_SHELF_CELL, EcologyGridModel.HEADWALL_SPRING_CELL]:
		if _cell_distance(cell, landmark) < LANDMARK_CLEARANCE_CELLS:
			return false
	# Keep the water-holding lows and the dam site open.
	for bowl in [EcologyGridModel.SHELTER_BOWL_CELL, EcologyGridModel.LONG_MEADOW_CELL, EcologyGridModel.NECK_CELL, EcologyGridModel.SINK_CELL]:
		if _cell_distance(cell, bowl) < BOWL_CLEARANCE_CELLS:
			return false
	for course_cell in watercourse:
		if _cell_distance(cell, course_cell) < WATERCOURSE_CLEARANCE_CELLS:
			return false
	# A cell that holds water rather than draining is a pool, not a plinth.
	return ecology.downhill_neighbor(cell) != cell


func _add_hoodoo(ecology, cell: Vector2i, rng: RandomNumberGenerator, shape: Dictionary) -> void:
	var height: float = shape["height"]
	var width: float = shape["width"]
	var world: Vector2 = ecology.world_position(cell.x, cell.y)
	var jitter := Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35))

	var body := StaticBody3D.new()
	body.name = "Hoodoo_%d_%d" % [cell.x, cell.y]
	body.position = Vector3(world.x + jitter.x, ecology.terrain_height(cell) - BASE_SINK, world.y + jitter.y)
	body.rotation = Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(0.0, TAU), rng.randf_range(-0.05, 0.05))
	add_child(body)
	var mass := Node3D.new()
	mass.name = "Mass"
	body.add_child(mass)

	var tint := Color("b2623a").lerp(Color("c98150"), rng.randf()).lerp(Color("8f4e33"), rng.randf() * 0.35)
	var noise := [rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU)]
	var capped: bool = shape["capped"]
	var column_height := height * (0.74 if capped else 1.0)
	var profile: Array
	if capped:
		profile = [[0.0, 1.0], [0.1, 0.7], [0.3, 0.6], [0.48, 0.47], [0.63, 0.55], [0.84, 0.3], [1.0, 0.25]]
	else:
		profile = [[0.0, 1.0], [0.15, 0.74], [0.45, 0.55], [0.72, 0.4], [0.9, 0.26], [1.0, 0.0]]
	for point in profile:
		if point[1] > 0.0:
			point[1] *= rng.randf_range(0.88, 1.12)
	var column := MeshInstance3D.new()
	column.mesh = _lathe(profile, column_height, width, 30, noise, 0.09, tint, not capped)
	column.material_override = material
	mass.add_child(column)

	if capped:
		var neck_radius: float = profile[profile.size() - 1][1] * width
		var cap_radius := maxf(neck_radius * 2.6, width * rng.randf_range(0.66, 0.92))
		var cap_height := (height - column_height) * rng.randf_range(1.0, 1.25) + 0.12
		var cap_profile := [[0.0, 0.5], [0.15, 0.88], [0.45, 1.0], [0.75, 0.84], [0.92, 0.5], [1.0, 0.0]]
		var cap := MeshInstance3D.new()
		cap.mesh = _lathe(cap_profile, cap_height, cap_radius, 14, [noise[1], noise[3], noise[0], noise[2]], 0.13, tint.lightened(0.05), true)
		cap.material_override = material
		cap.name = "Cap"
		cap.position = Vector3(rng.randf_range(-0.14, 0.14), column_height - 0.12, rng.randf_range(-0.14, 0.14))
		cap.rotation = Vector3(rng.randf_range(-0.26, 0.26), 0.0, rng.randf_range(-0.26, 0.26))
		mass.add_child(cap)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var cylinder := CylinderShape3D.new()
	cylinder.radius = width * 0.62
	cylinder.height = height + BASE_SINK
	collision.shape = cylinder
	collision.position.y = cylinder.height * 0.5
	body.add_child(collision)

	hoodoo_cells.append(cell)
	hoodoo_heights[cell] = height
	hoodoo_widths[cell] = width


# A surface of revolution from a (fraction of height, fraction of radius)
# profile, roughened with low-frequency lobes and horizontal ledges so each
# spire weathers differently.
func _lathe(profile: Array, height: float, radius: float, rings: int, noise: Array, roughness: float, tint: Color, close_top: bool) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in rings + 1:
		var t := float(ring) / float(rings)
		var base_radius := _profile_radius(profile, t) * radius
		var y := t * height
		var shade := lerpf(0.86, 1.0, clampf(t * 1.6, 0.0, 1.0))
		for segment in RING_SEGMENTS:
			var angle := TAU * float(segment) / float(RING_SEGMENTS)
			var lobes := 0.55 * sin(3.0 * angle + noise[0] + y * 1.7) + 0.35 * sin(5.0 * angle + noise[1] - y * 2.3) + 0.3 * sin(2.0 * angle + noise[2] + y * 0.8)
			var ledges := 0.45 * sin(y * 8.5 + noise[3])
			var r := maxf(0.0, base_radius * (1.0 + roughness * (lobes + ledges)))
			tool.set_color(tint * shade)
			tool.add_vertex(Vector3(cos(angle) * r, y, sin(angle) * r))
	for ring in rings:
		for segment in RING_SEGMENTS:
			var next := (segment + 1) % RING_SEGMENTS
			var a := ring * RING_SEGMENTS + segment
			var b := ring * RING_SEGMENTS + next
			var c := (ring + 1) * RING_SEGMENTS + next
			var d := (ring + 1) * RING_SEGMENTS + segment
			tool.add_index(a)
			tool.add_index(b)
			tool.add_index(c)
			tool.add_index(a)
			tool.add_index(c)
			tool.add_index(d)
	if close_top:
		var apex := (rings + 1) * RING_SEGMENTS
		tool.set_color(tint)
		tool.add_vertex(Vector3(0.0, height, 0.0))
		for segment in RING_SEGMENTS:
			tool.add_index(rings * RING_SEGMENTS + segment)
			tool.add_index(rings * RING_SEGMENTS + (segment + 1) % RING_SEGMENTS)
			tool.add_index(apex)
	tool.generate_normals()
	return tool.commit()


func _profile_radius(profile: Array, t: float) -> float:
	for index in range(1, profile.size()):
		var upper: Array = profile[index]
		if t <= upper[0]:
			var lower: Array = profile[index - 1]
			var span: float = upper[0] - lower[0]
			var blend := 0.5 - 0.5 * cos(PI * (t - lower[0]) / span)
			return lerpf(lower[1], upper[1], blend)
	return profile[profile.size() - 1][1]


func _far_from(cell: Vector2i, others: Array, distance: float) -> bool:
	for other in others:
		if _cell_distance(cell, other) < distance:
			return false
	return true


func _cell_distance(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a).distance_to(Vector2(b))
