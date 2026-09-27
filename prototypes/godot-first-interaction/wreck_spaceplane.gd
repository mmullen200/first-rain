extends Node3D

# THROWAWAY PROTOTYPE.
# The crashed spaceplane: a lifting-body shuttle with a white tiled upper hull,
# black heat-shield belly and nose cap, a canted outboard wing each side and a
# central tail fin. It came down nose-first and slewed onto its right side; the
# right wing tore off and lies propped beside the hull. Presentation only: it
# has no collision and no gameplay state. Nose faces local +Z, the ground is
# y = 0, and the right side is local -X.

const LENGTH := 6.0
const HALF_WIDTH := 1.1
const TOP_HEIGHT := 0.95
const BELLY_DEPTH := 0.35
const CANOPY_BULGE := 0.2
const STATIONS := 56
const RING := 44

const HULL_WHITE := Color("f0efea")
const TILE_SHADE := Color("e8e6e0")
const SHIELD_BLACK := Color("1c1e20")
const WINDOW_BLACK := Color("0c0e11")
const SCORCH := Color("4a4540")
const AFT_GREY := Color("3b4045")

var hull_material: StandardMaterial3D
var white_material: StandardMaterial3D
var black_material: StandardMaterial3D
var grey_material: StandardMaterial3D
var scorch_material: StandardMaterial3D


func _init() -> void:
	name = "WreckSpaceplane"
	hull_material = _material(Color.WHITE, 0.5)
	hull_material.vertex_color_use_as_albedo = true
	white_material = _material(HULL_WHITE, 0.55)
	black_material = _material(SHIELD_BLACK, 0.7)
	grey_material = _material(AFT_GREY, 0.45)
	grey_material.metallic = 0.4
	scorch_material = _material(SCORCH, 0.95)
	_build()


func _build() -> void:
	# The hull rests on its belly, sunk slightly into the ground, pitched nose
	# down and rolled toward the side that lost its wing.
	var body := Node3D.new()
	body.name = "Body"
	body.position = Vector3(0.0, BELLY_DEPTH - 0.12, 0.0)
	body.rotation = Vector3(0.07, 0.0, 0.09)
	add_child(body)

	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = _hull_mesh()
	hull.material_override = hull_material
	body.add_child(hull)
	_build_aft(body)

	# Left wing: intact, swept back and canted steeply upward.
	var left_root := Node3D.new()
	left_root.position = Vector3(HALF_WIDTH * 0.86, -0.05, -1.55)
	left_root.rotation.z = 0.95
	body.add_child(left_root)
	_build_wing(left_root, 1.0, 1.9)

	# Right wing: a torn stub at the root; the rest lies on the ground.
	var right_root := Node3D.new()
	right_root.position = Vector3(-HALF_WIDTH * 0.86, -0.05, -1.55)
	right_root.rotation.z = PI - 0.95
	body.add_child(right_root)
	_build_wing(right_root, 1.0, 1.9, 0.0, 0.22)
	var tear := _part(right_root, _box(Vector3(0.06, 0.14, 1.45)), scorch_material, Vector3(0.42, 0.0, -0.18))
	tear.rotation.y = 0.2

	var torn_wing := Node3D.new()
	torn_wing.name = "TornWing"
	torn_wing.position = Vector3(-2.35, 0.05, 0.35)
	torn_wing.rotation = Vector3(0.0, 2.55, 0.42)
	add_child(torn_wing)
	_build_wing(torn_wing, 1.0, 1.9, 0.22, 1.0)

	# Central tail fin and the two small upper fins beside it.
	var fin := Node3D.new()
	fin.position = Vector3(0.0, TOP_HEIGHT * 0.62, -2.2)
	fin.rotation.z = PI * 0.5
	body.add_child(fin)
	_build_wing(fin, 0.8, 1.25)
	for side in [-1.0, 1.0]:
		var small_fin := Node3D.new()
		small_fin.position = Vector3(0.42 * side, TOP_HEIGHT * 0.55, -2.35)
		small_fin.rotation.z = PI * 0.5 - 0.95 * side
		body.add_child(small_fin)
		_build_wing(small_fin, 0.4, 0.55)

	# Scattered hull tiles and a scorched skid scar behind the tail.
	var shards := [
		[Vector3(-1.6, 0.03, 2.4), 0.4, true],
		[Vector3(-3.1, 0.03, -0.9), 1.3, false],
		[Vector3(0.9, 0.03, -4.0), 2.2, true],
		[Vector3(-0.8, 0.03, -4.6), 0.7, false],
	]
	for shard in shards:
		var tile := _part(self, _box(Vector3(0.34, 0.05, 0.26)), black_material if shard[2] else white_material, shard[0])
		tile.rotation = Vector3(0.1, shard[1], -0.08)
	var scar := _part(self, _box(Vector3(1.5, 0.02, 3.2)), scorch_material, Vector3(0.1, 0.012, -4.3))
	scar.rotation.y = 0.1


func _build_aft(body: Node3D) -> void:
	var z := -LENGTH * 0.5
	var bulkhead := MeshInstance3D.new()
	bulkhead.mesh = _aft_cap_mesh()
	bulkhead.material_override = grey_material
	body.add_child(bulkhead)
	for offset in [Vector2(0.0, 0.42), Vector2(-0.42, 0.14), Vector2(0.42, 0.14)]:
		var bell := _part(body, _cylinder(0.12, 0.2, 0.34), grey_material, Vector3(offset.x, offset.y, z - 0.14))
		bell.rotation.x = -PI * 0.5
		var throat := _part(body, _cylinder(0.14, 0.15, 0.05), black_material, Vector3(offset.x, offset.y, z - 0.3))
		throat.rotation.x = -PI * 0.5


# A tapered, swept flat panel whose span runs along local +X from the pivot and
# whose leading edge faces +Z. Only the part of the span between from and to is
# built, starting at the pivot, so a wing can be split where it tore. The
# leading edge and tip are heat-shield black.
func _build_wing(pivot: Node3D, scale_value: float, span: float, from := 0.0, to := 1.0) -> void:
	var root_chord := 2.0 * scale_value
	var tip_chord := 0.75 * scale_value
	var sweep := 0.9 * scale_value
	var thickness := 0.12 * scale_value
	var lead_in := root_chord * 0.5 - sweep * from
	var lead_out := root_chord * 0.5 - sweep * to
	var chord_in := lerpf(root_chord, tip_chord, from)
	var chord_out := lerpf(root_chord, tip_chord, to)
	var thick_in := lerpf(thickness, thickness * 0.55, from)
	var thick_out := lerpf(thickness, thickness * 0.55, to)
	var outer := Vector3((to - from) * span, 0.0, 0.0)
	var edge_in := chord_in * 0.16
	var edge_out := chord_out * 0.16
	pivot.add_child(_mesh_node(_slab(Vector3.ZERO, outer, lead_in - edge_in, lead_in - chord_in, lead_out - edge_out, lead_out - chord_out, thick_in, thick_out), white_material))
	pivot.add_child(_mesh_node(_slab(Vector3.ZERO, outer, lead_in, lead_in - edge_in, lead_out, lead_out - edge_out, thick_in * 1.05, thick_out * 1.05), black_material))
	if to >= 1.0:
		var cap := Vector3(0.12 * scale_value, 0.0, 0.0)
		pivot.add_child(_mesh_node(_slab(outer - cap, outer, lead_out, lead_out - chord_out, lead_out, lead_out - chord_out, thick_out * 1.08, thick_out * 1.08), black_material))


# Lofted lifting body. Stations run from the aft bulkhead (t = 0) to the nose
# (t = 1); each cross-section is a rounded upper arch over a flatter belly.
func _hull_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in range(STATIONS):
		for r in range(RING):
			var t0 := float(s) / STATIONS
			var t1 := float(s + 1) / STATIONS
			var u0 := float(r) / RING
			var u1 := float(r + 1) / RING
			var color := _hull_color((t0 + t1) * 0.5, (u0 + u1) * 0.5, s, r)
			var corners := [Vector2(t0, u0), Vector2(t0, u1), Vector2(t1, u1), Vector2(t0, u0), Vector2(t1, u1), Vector2(t1, u0)]
			for corner in corners:
				tool.set_color(color)
				tool.set_normal(_hull_normal(corner.x, corner.y))
				tool.add_vertex(_hull_point(corner.x, corner.y))
	return tool.commit()


# Flat plate closing the hull at the aft bulkhead.
func _aft_cap_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := Vector3(0.0, TOP_HEIGHT * 0.3, -LENGTH * 0.5)
	for r in range(RING):
		for vertex in [centre, _hull_point(0.0, float(r + 1) / RING), _hull_point(0.0, float(r) / RING)]:
			tool.set_normal(Vector3.FORWARD)
			tool.add_vertex(vertex)
	return tool.commit()


func _hull_point(t: float, u: float) -> Vector3:
	var nose := 0.46
	var profile := 0.88 + 0.12 * t / nose
	if t > nose:
		var k := (t - nose) / (1.0 - nose)
		profile = sqrt(maxf(0.0, 1.0 - k * k))
	var width := HALF_WIDTH * profile
	var top := TOP_HEIGHT * pow(profile, 0.8) + CANOPY_BULGE * exp(-pow((t - 0.68) / 0.11, 2.0)) * profile
	var belly := BELLY_DEPTH * pow(profile, 0.6)
	var centre := -0.16 * smoothstep(0.5, 1.0, t)
	var theta := u * TAU
	var c := cos(theta)
	var s := sin(theta)
	var x := signf(c) * pow(absf(c), 0.75) * width
	var y := centre
	if s >= 0.0:
		y += pow(s, 0.75) * top
	else:
		y -= pow(-s, 0.4) * belly
	return Vector3(x, y, lerpf(-LENGTH * 0.5, LENGTH * 0.5, t))


func _hull_normal(t: float, u: float) -> Vector3:
	if t >= 0.999:
		return Vector3(0.0, -0.15, 1.0).normalized()
	var du := 0.002
	var dt := 0.002
	var along := _hull_point(minf(t + dt, 1.0), u) - _hull_point(maxf(t - dt, 0.0), u)
	var around := _hull_point(t, u + du) - _hull_point(t, u - du)
	var normal := around.cross(along).normalized()
	var point := _hull_point(t, u)
	if normal.dot(Vector3(point.x, point.y - 0.2, 0.0)) < 0.0:
		normal = -normal
	return normal


func _hull_color(t: float, u: float, station: int, ring_index: int) -> Color:
	var upper := u < 0.5
	if not upper or t > 0.93:
		return SHIELD_BLACK
	var c := cos(u * TAU)
	# Cockpit windows sweep across the canopy bulge.
	if t > 0.66 and t < 0.77 and absf(c) < 0.62 and absf(c) > 0.06 and sin(u * TAU) > 0.5:
		return WINDOW_BLACK
	# Black chines along the lower edge of the forward hull.
	if t > 0.55 and sin(u * TAU) < 0.12:
		return SHIELD_BLACK
	# Scorching where the right wing tore away.
	if c < -0.55 and t < 0.42 and t > 0.1 and sin(u * TAU) < 0.55:
		return SCORCH.lerp(HULL_WHITE, 0.35 + 0.3 * absf(sin(float(station) * 1.7)))
	return TILE_SHADE if (station / 2 + ring_index / 2) % 2 == 0 else HULL_WHITE


# Tapered box between an inner and outer edge; each edge has its own leading
# and trailing z and thickness.
func _slab(inner: Vector3, outer: Vector3, inner_lead: float, inner_trail: float, outer_lead: float, outer_trail: float, inner_thickness: float, outer_thickness: float) -> ArrayMesh:
	var corners := []
	for side in [[inner, inner_lead, inner_trail, inner_thickness], [outer, outer_lead, outer_trail, outer_thickness]]:
		var base: Vector3 = side[0]
		var half: float = side[3] * 0.5
		corners.append(base + Vector3(0.0, half, side[1]))
		corners.append(base + Vector3(0.0, half, side[2]))
		corners.append(base + Vector3(0.0, -half, side[2]))
		corners.append(base + Vector3(0.0, -half, side[1]))
	var faces := [[0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5], [0, 3, 2, 1], [4, 5, 6, 7]]
	var centre := Vector3.ZERO
	for corner in corners:
		centre += corner
	centre /= corners.size()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		var a: Vector3 = corners[face[0]]
		var b: Vector3 = corners[face[1]]
		var c: Vector3 = corners[face[2]]
		var d: Vector3 = corners[face[3]]
		var normal := (c - a).cross(b - a).normalized()
		if normal.dot((a + c) * 0.5 - centre) < 0.0:
			normal = -normal
		for vertex in [a, b, c, a, c, d]:
			tool.set_normal(normal)
			tool.add_vertex(vertex)
	return tool.commit()


func _mesh_node(mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	return instance


func _part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := _mesh_node(mesh, material)
	instance.position = at
	parent.add_child(instance)
	return instance


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _cylinder(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	return mesh


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	# Procedural faces carry explicit outward normals; draw both sides so
	# winding order never hides a panel.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
