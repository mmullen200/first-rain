extends Node3D

# THROWAWAY PROTOTYPE.
# The crashed spaceplane: a lifting-body shuttle with a white tiled upper hull,
# black heat-shield belly and nose cap, a canted outboard wing each side and a
# central tail fin. It came down nose-first and slewed onto its left side; the
# left wing tore off and leans against the hull. An open hatch in the left side
# leads into a small cabin with a cockpit, two seats and an 8-bit ship-status
# screen. Nose faces local +Z, the ground is y = 0, and the left side is local
# +X. The model is drawn at model scale inside a child node enlarged by SIZE, so
# the wreck is about 10.5 m long; collision walls, lights and cameras sit on
# this unscaled root in metres.

const ShipScreen = preload("res://ship_screen.gd")

const SIZE := 1.75
const LENGTH := 6.0
const HALF_WIDTH := 1.1
const TOP_HEIGHT := 1.05
const BELLY_DEPTH := 0.35
const CANOPY_BULGE := 0.2
const STATIONS := 56
const RING := 44

# Cabin layout, in model units in the hull's own frame.
const FLOOR_Y := -0.12
const LINER := 0.05
const CABIN_STATIONS := Vector2i(8, 45)
const HATCH_STATIONS := Vector2i(20, 28)
const HATCH_RINGS := Vector2i(-1, 8)
const INNER_WALL_INSET := 0.27
const SEAT_Z := 0.75
const CONSOLE_Z := 1.5
const CONSOLE_DEPTH := 0.28
const SCREEN_CENTRE := Vector3(0.0, FLOOR_Y + 0.72, 1.44)
const SCREEN_TILT := 0.18

const HULL_WHITE := Color("f0efea")
const TILE_SHADE := Color("e8e6e0")
const SHIELD_BLACK := Color("1c1e20")
const WINDOW_BLACK := Color("0c0e11")
const SCORCH := Color("4a4540")
const AFT_GREY := Color("3b4045")
const PANEL := Color("5b6874")
const PANEL_DARK := Color("4a5560")
const SEAM := Color("2d343b")
const CEILING_LIGHT := Color("f6e7a8")
const ACCENT := Color("c9652c")
const WINDOW_INSIDE := Color("1b2b3e")
const FLOOR_LIGHT := Color("41474d")
const FLOOR_DARK := Color("33383d")
const SEAT_RED := Color("8c3b2b")

var hull_material: StandardMaterial3D
var white_material: StandardMaterial3D
var black_material: StandardMaterial3D
var grey_material: StandardMaterial3D
var scorch_material: StandardMaterial3D
var seat_material: StandardMaterial3D

var model: Node3D
var body: Node3D
var interior_camera: Camera3D
var console_camera: Camera3D
var ship_screen: RefCounted


func _init() -> void:
	name = "WreckSpaceplane"
	hull_material = _material(Color.WHITE, 0.5)
	hull_material.vertex_color_use_as_albedo = true
	white_material = _material(HULL_WHITE, 0.55)
	black_material = _material(SHIELD_BLACK, 0.7)
	grey_material = _material(AFT_GREY, 0.45)
	grey_material.metallic = 0.4
	scorch_material = _material(SCORCH, 0.95)
	seat_material = _material(SEAT_RED, 0.8)
	ship_screen = ShipScreen.new()
	_build()


# True when a world position is inside the cabin, past the hatch.
func is_inside(world: Vector3) -> bool:
	var local := _world_to_body(world)
	var t := _t_at(local.z)
	if t < float(CABIN_STATIONS.x) / STATIONS or local.z > CONSOLE_Z - CONSOLE_DEPTH * 0.5:
		return false
	return absf(local.x) < _half_width(t) - 0.3


# Height the Astronaut stands at: the cabin floor inside, a short ramp through
# the hatch, and the given terrain height everywhere else.
func standing_height(world: Vector3, terrain_height: float) -> float:
	var local := _world_to_body(world)
	var t := _t_at(local.z)
	if t < float(CABIN_STATIONS.x) / STATIONS or t > float(CABIN_STATIONS.y) / STATIONS:
		return terrain_height
	var edge := _half_width(t) - 0.3
	var blend := 1.0 if absf(local.x) <= edge else 0.0
	var in_hatch := local.x > 0.0 and t >= float(HATCH_STATIONS.x) / STATIONS and t <= float(HATCH_STATIONS.y) / STATIONS
	if in_hatch:
		blend = clampf((edge + 0.55 - local.x) / 0.55, 0.0, 1.0)
	if blend <= 0.0:
		return terrain_height
	var floor_point := model.global_transform * (body.transform * Vector3(0.0, FLOOR_Y, 0.0))
	var normal := (model.global_basis * body.basis * Vector3.UP).normalized()
	var floor_height := floor_point.y - (normal.x * (world.x - floor_point.x) + normal.z * (world.z - floor_point.z)) / normal.y
	return lerpf(terrain_height, floor_height, blend)


# World position of a point given in the cabin's model coordinates.
func cabin_point(local: Vector3) -> Vector3:
	return model.global_transform * (body.transform * local)


func screen_position() -> Vector3:
	return cabin_point(SCREEN_CENTRE)


func show_status(readings: Dictionary) -> void:
	ship_screen.render(readings)


func _build() -> void:
	model = Node3D.new()
	model.name = "Model"
	model.scale = Vector3.ONE * SIZE
	add_child(model)

	# The hull rests on its belly, sunk slightly into the ground and rolled
	# toward the side that lost its wing.
	body = Node3D.new()
	body.name = "Body"
	body.position = Vector3(0.0, BELLY_DEPTH - 0.12, 0.0)
	body.rotation = Vector3(0.0, 0.0, -0.12)
	model.add_child(body)

	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = _hull_mesh()
	hull.material_override = hull_material
	body.add_child(hull)
	_build_aft(body)
	_build_cabin()

	# Right wing: intact, swept back and canted steeply upward.
	var right_root := Node3D.new()
	right_root.position = Vector3(-_half_width(_t_at(-1.55)) + 0.03, -0.05, -1.55)
	right_root.rotation.z = PI - 0.95
	body.add_child(right_root)
	_build_wing(right_root, 1.0, 1.9)

	# Left wing: a torn stub at the root; the rest leans against the hull.
	var left_root := Node3D.new()
	left_root.position = Vector3(_half_width(_t_at(-1.55)) - 0.03, -0.05, -1.55)
	left_root.rotation.z = 0.95
	body.add_child(left_root)
	_build_wing(left_root, 1.0, 1.9, 0.0, 0.22)
	var tear := _part(left_root, _box(Vector3(0.06, 0.14, 1.45)), scorch_material, Vector3(0.42, 0.0, -0.18))
	tear.rotation.y = 0.2

	var torn_wing := Node3D.new()
	torn_wing.name = "TornWing"
	torn_wing.position = Vector3(1.2, 1.1, 2.0)
	torn_wing.rotation = Vector3(0.0, -2.55, 0.42 + PI)
	model.add_child(torn_wing)
	_build_wing(torn_wing, 1.0, 1.9, 0.22, 1.0)

	# Central tail fin and the two small upper fins beside it.
	var fin := Node3D.new()
	fin.position = Vector3(0.0, _roof_height(-2.2, 0.0), -2.2)
	fin.rotation.z = PI * 0.5
	body.add_child(fin)
	_build_wing(fin, 0.8, 1.25)
	for side in [-1.0, 1.0]:
		var small_fin := Node3D.new()
		small_fin.position = Vector3(0.42 * side, _roof_height(-2.35, 0.42), -2.35)
		small_fin.rotation.z = PI * 0.5 - 0.95 * side
		body.add_child(small_fin)
		_build_wing(small_fin, 0.4, 0.55)

	# Scattered hull tiles and a scorched skid scar behind the tail.
	var shards := [
		[Vector3(1.6, 0.03, 2.4), -0.4, true],
		[Vector3(3.1, 0.03, -0.9), -1.3, false],
		[Vector3(-0.9, 0.03, -4.0), -2.2, true],
		[Vector3(0.8, 0.03, -4.6), -0.7, false],
	]
	for shard in shards:
		var tile := _part(model, _box(Vector3(0.34, 0.05, 0.26)), black_material if shard[2] else white_material, shard[0])
		tile.rotation = Vector3(0.1, shard[1], 0.08)
	var scar := _part(model, _box(Vector3(1.5, 0.02, 3.2)), scorch_material, Vector3(-0.1, 0.012, -4.3))
	scar.rotation.y = -0.1
	_build_walls()


# Cabin lining, floor, cockpit seats and console, the status screen, lights and
# the two interior cameras.
func _build_cabin() -> void:
	var interior := _material(Color.WHITE, 0.85)
	interior.vertex_color_use_as_albedo = true
	body.add_child(_mesh_node(_liner_mesh(), interior))
	body.add_child(_mesh_node(_floor_mesh(), interior))

	var frame_material := _material(Color("2a3036"), 0.6)
	for side in [-1.0, 1.0]:
		var x: float = 0.34 * side
		_part(body, _box(Vector3(0.1, 0.24, 0.1)), frame_material, Vector3(x, FLOOR_Y + 0.12, SEAT_Z))
		_part(body, _box(Vector3(0.3, 0.07, 0.3)), seat_material, Vector3(x, FLOOR_Y + 0.27, SEAT_Z))
		var back := _part(body, _box(Vector3(0.3, 0.44, 0.07)), seat_material, Vector3(x, FLOOR_Y + 0.52, SEAT_Z - 0.16))
		back.rotation.x = -0.2
		var headrest := _part(body, _box(Vector3(0.18, 0.1, 0.07)), frame_material, Vector3(x, FLOOR_Y + 0.8, SEAT_Z - 0.21))
		headrest.rotation.x = -0.2

	_part(body, _box(Vector3(1.1, 0.4, CONSOLE_DEPTH)), frame_material, Vector3(0.0, FLOOR_Y + 0.2, CONSOLE_Z))
	var desk := _part(body, _box(Vector3(1.1, 0.05, 0.36)), _material(Color("3a424a"), 0.5), Vector3(0.0, FLOOR_Y + 0.43, CONSOLE_Z - 0.06))
	desk.rotation.x = -0.35
	# Rows of chunky indicator lights across the desk.
	var lamp_colors := [Color("ff5a48"), Color("ffc34d"), Color("79f59a"), Color("5ab8ff")]
	for i in range(12):
		var lamp := _part(desk, _box(Vector3(0.05, 0.03, 0.04)), _glow_material(lamp_colors[(i * 7) % lamp_colors.size()]), Vector3(-0.47 + float(i % 6) * 0.07 + (0.52 if i >= 6 else 0.0), 0.03, -0.08 + float(i % 2) * 0.1))
		lamp.name = "Lamp%d" % i

	var screen_frame := Node3D.new()
	screen_frame.name = "ShipScreen"
	screen_frame.position = SCREEN_CENTRE
	screen_frame.rotation.x = SCREEN_TILT
	body.add_child(screen_frame)
	_part(screen_frame, _box(Vector3(0.56, 0.36, 0.04)), frame_material, Vector3.ZERO)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5 * float(ShipScreen.HEIGHT) / ShipScreen.WIDTH)
	var screen_material := StandardMaterial3D.new()
	screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_material.albedo_texture = ship_screen.texture
	screen_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var display := _part(screen_frame, quad, screen_material, Vector3(0.0, 0.0, -0.021))
	display.rotation.y = PI
	_part(body, _box(Vector3(0.08, 0.3, 0.08)), frame_material, Vector3(0.0, FLOOR_Y + 0.5, CONSOLE_Z - 0.02))

	var cabin_light := OmniLight3D.new()
	cabin_light.name = "CabinLight"
	cabin_light.light_color = Color("f3e6c4")
	cabin_light.light_energy = 1.3
	cabin_light.omni_range = 5.5
	cabin_light.position = _to_root(Vector3(0.0, 0.75, -0.6))
	add_child(cabin_light)
	var screen_light := OmniLight3D.new()
	screen_light.name = "ScreenGlow"
	screen_light.light_color = Color("79f59a")
	screen_light.light_energy = 0.5
	screen_light.omni_range = 1.8
	screen_light.position = _to_root(SCREEN_CENTRE + Vector3(0.0, 0.0, -0.3))
	add_child(screen_light)

	# A fixed camera in the aft corner looks forward over the whole cabin.
	var up := (model.basis * body.basis * Vector3.UP).normalized()
	interior_camera = Camera3D.new()
	interior_camera.name = "InteriorCamera"
	interior_camera.fov = 70.0
	interior_camera.near = 0.05
	var eye := _to_root(Vector3(-0.12, 0.84, -1.85))
	interior_camera.transform = Transform3D(Basis.looking_at(_to_root(Vector3(0.2, 0.0, 1.1)) - eye, up), eye)
	interior_camera.h_offset = 0.25
	add_child(interior_camera)

	# A close camera squarely in front of the screen, for consulting it. It is
	# shifted so the screen sits clear of the scanner panel.
	console_camera = Camera3D.new()
	console_camera.name = "ConsoleCamera"
	console_camera.fov = 60.0
	console_camera.near = 0.02
	var screen_basis := body.basis * Basis(Vector3.RIGHT, SCREEN_TILT)
	var screen_normal := (model.basis * screen_basis * Vector3.FORWARD).normalized()
	var screen_up := (model.basis * screen_basis * Vector3.UP).normalized()
	var screen_eye := _to_root(SCREEN_CENTRE) + screen_normal * 0.78
	console_camera.transform = Transform3D(Basis.looking_at(-screen_normal, screen_up), screen_eye)
	console_camera.h_offset = 0.12
	console_camera.v_offset = -0.06
	add_child(console_camera)


# Collision in metres on the unscaled root: an outer wall around the hull
# outline, an inner wall around the cabin floor, and a gap through both at the
# hatch. The small tilt of the hull is ignored.
func _build_walls() -> void:
	var walls := StaticBody3D.new()
	walls.name = "HullWalls"
	add_child(walls)
	var hatch_from := float(HATCH_STATIONS.x) / STATIONS
	var hatch_to := float(HATCH_STATIONS.y) / STATIONS
	var steps := STATIONS / 2
	for side in [-1.0, 1.0]:
		for i in range(steps):
			var t0 := float(i) / steps
			var t1 := float(i + 1) / steps
			if side > 0.0 and t0 >= hatch_from - 0.001 and t1 <= hatch_to + 0.001:
				continue
			_wall(walls, Vector2(side * _half_width(t0), _z_at(t0)), Vector2(side * _half_width(t1), _z_at(t1)))
	_wall(walls, Vector2(-_half_width(0.0), _z_at(0.0)), Vector2(_half_width(0.0), _z_at(0.0)))

	var cabin_from := float(CABIN_STATIONS.x) / STATIONS
	var console_t := _t_at(CONSOLE_Z - CONSOLE_DEPTH * 0.5)
	var ts := []
	var t := cabin_from
	while t < console_t:
		ts.append(t)
		t += 1.0 / steps
	ts.append(console_t)
	for side in [-1.0, 1.0]:
		for i in range(ts.size() - 1):
			var a: float = ts[i]
			var b: float = ts[i + 1]
			if side > 0.0 and a >= hatch_from - 0.001 and b <= hatch_to + 0.001:
				continue
			_wall(walls, Vector2(side * _inner_half_width(a), _z_at(a)), Vector2(side * _inner_half_width(b), _z_at(b)))
	_wall(walls, Vector2(-_inner_half_width(cabin_from), _z_at(cabin_from)), Vector2(_inner_half_width(cabin_from), _z_at(cabin_from)))
	_wall(walls, Vector2(-_inner_half_width(console_t), _z_at(console_t)), Vector2(_inner_half_width(console_t), _z_at(console_t)))
	# Close the space between the two walls on either side of the hatch.
	for hatch_t in [hatch_from, hatch_to]:
		_wall(walls, Vector2(_inner_half_width(hatch_t), _z_at(hatch_t)), Vector2(_half_width(hatch_t), _z_at(hatch_t)))
	# The two seats.
	for side in [-1.0, 1.0]:
		var seat := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.32, 1.0, 0.4) * SIZE
		seat.shape = shape
		seat.position = Vector3(0.34 * side, 0.5, SEAT_Z - 0.06) * SIZE
		walls.add_child(seat)


func _wall(walls: StaticBody3D, from: Vector2, to: Vector2) -> void:
	var a := from * SIZE
	var b := to * SIZE
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var wall := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.12, 2.4, length + 0.1)
	wall.shape = shape
	var middle := (a + b) * 0.5
	wall.position = Vector3(middle.x, 1.2, middle.y)
	wall.rotation.y = atan2(b.x - a.x, b.y - a.y)
	walls.add_child(wall)


func _build_aft(parent: Node3D) -> void:
	var z := -LENGTH * 0.5
	var bulkhead := MeshInstance3D.new()
	bulkhead.mesh = _aft_cap_mesh()
	bulkhead.material_override = grey_material
	parent.add_child(bulkhead)
	for offset in [Vector2(0.0, 0.42), Vector2(-0.42, 0.14), Vector2(0.42, 0.14)]:
		var bell := _part(parent, _cylinder(0.12, 0.2, 0.34), grey_material, Vector3(offset.x, offset.y, z - 0.14))
		bell.rotation.x = -PI * 0.5
		var throat := _part(parent, _cylinder(0.14, 0.15, 0.05), black_material, Vector3(offset.x, offset.y, z - 0.3))
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
# (t = 1); each cross-section is a rounded upper arch over a flatter belly. The
# hatch is left open in the left side.
func _hull_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in range(STATIONS):
		for r in range(RING):
			if _in_hatch(s, r):
				continue
			var color := _hull_color((float(s) + 0.5) / STATIONS, (float(r) + 0.5) / RING, s, r)
			if _in_hatch(s - 1, r) or _in_hatch(s + 1, r) or _in_hatch(s, r - 1) or _in_hatch(s, r + 1):
				color = AFT_GREY
			_quad(tool, s, r, color, 0.0)
	return tool.commit()


# The cabin lining: the hull's inner surface offset inward, with inward normals,
# closed by an aft bulkhead and a forward bulkhead behind the console, plus the
# door jambs that join it to the outer hull around the hatch.
func _liner_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in range(CABIN_STATIONS.x, CABIN_STATIONS.y):
		for r in range(RING):
			if not _in_hatch(s, r):
				_quad(tool, s, r, _liner_color(s, r), LINER)
	for cap in [[CABIN_STATIONS.x, Vector3.BACK], [CABIN_STATIONS.y, Vector3.FORWARD]]:
		var t: float = float(cap[0]) / STATIONS
		var centre := Vector3(0.0, 0.35, _z_at(t))
		for r in range(RING):
			_triangle(tool, [centre, _liner_point(t, float(r) / RING), _liner_point(t, float(r + 1) / RING)], [cap[1], cap[1], cap[1]], PANEL_DARK if r % 4 < 2 else PANEL)
	var t0 := float(HATCH_STATIONS.x) / STATIONS
	var t1 := float(HATCH_STATIONS.y) / STATIONS
	var u0 := float(HATCH_RINGS.x) / RING
	var u1 := float(HATCH_RINGS.y) / RING
	var middle := _hull_point((t0 + t1) * 0.5, (u0 + u1) * 0.5)
	var edges := []
	for i in range(HATCH_STATIONS.y - HATCH_STATIONS.x):
		var a := float(HATCH_STATIONS.x + i) / STATIONS
		var b := float(HATCH_STATIONS.x + i + 1) / STATIONS
		edges.append([Vector2(a, u0), Vector2(b, u0)])
		edges.append([Vector2(a, u1), Vector2(b, u1)])
	for i in range(HATCH_RINGS.y - HATCH_RINGS.x):
		var a := float(HATCH_RINGS.x + i) / RING
		var b := float(HATCH_RINGS.x + i + 1) / RING
		edges.append([Vector2(t0, a), Vector2(t0, b)])
		edges.append([Vector2(t1, a), Vector2(t1, b)])
	for edge in edges:
		var p: Vector2 = edge[0]
		var q: Vector2 = edge[1]
		var outer_p := _hull_point(p.x, p.y)
		var outer_q := _hull_point(q.x, q.y)
		var inner_p := _liner_point(p.x, p.y)
		var inner_q := _liner_point(q.x, q.y)
		var normal := (outer_q - outer_p).cross(inner_p - outer_p).normalized()
		if normal.dot(middle - outer_p) < 0.0:
			normal = -normal
		_triangle(tool, [outer_p, outer_q, inner_q], [normal, normal, normal], AFT_GREY)
		_triangle(tool, [outer_p, inner_q, inner_p], [normal, normal, normal], AFT_GREY)
	return tool.commit()


# Flat cabin floor following the lining, in a chunky checkerboard.
func _floor_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var across := 8
	for s in range(CABIN_STATIONS.x, CABIN_STATIONS.y):
		var t0 := float(s) / STATIONS
		var t1 := float(s + 1) / STATIONS
		var w0 := _half_width(t0) - LINER - 0.02
		var w1 := _half_width(t1) - LINER - 0.02
		for k in range(across):
			var f0 := float(k) / across * 2.0 - 1.0
			var f1 := float(k + 1) / across * 2.0 - 1.0
			var a := Vector3(w0 * f0, FLOOR_Y, _z_at(t0))
			var b := Vector3(w0 * f1, FLOOR_Y, _z_at(t0))
			var c := Vector3(w1 * f1, FLOOR_Y, _z_at(t1))
			var d := Vector3(w1 * f0, FLOOR_Y, _z_at(t1))
			var color := FLOOR_LIGHT if (s / 2 + k) % 2 == 0 else FLOOR_DARK
			_triangle(tool, [a, b, c], [Vector3.UP, Vector3.UP, Vector3.UP], color)
			_triangle(tool, [a, c, d], [Vector3.UP, Vector3.UP, Vector3.UP], color)
	return tool.commit()


func _quad(tool: SurfaceTool, s: int, r: int, color: Color, inset: float) -> void:
	var t0 := float(s) / STATIONS
	var t1 := float(s + 1) / STATIONS
	var u0 := float(r) / RING
	var u1 := float(r + 1) / RING
	var points := []
	var normals := []
	for corner in [Vector2(t0, u0), Vector2(t0, u1), Vector2(t1, u1), Vector2(t1, u0)]:
		if inset > 0.0:
			points.append(_liner_point(corner.x, corner.y))
			normals.append(-_hull_normal(corner.x, corner.y))
		else:
			points.append(_hull_point(corner.x, corner.y))
			normals.append(_hull_normal(corner.x, corner.y))
	_triangle(tool, [points[0], points[1], points[2]], [normals[0], normals[1], normals[2]], color)
	_triangle(tool, [points[0], points[2], points[3]], [normals[0], normals[2], normals[3]], color)


# Emits one triangle wound so its front face is the side its normals point to
# (Godot treats clockwise triangles as front-facing).
func _triangle(tool: SurfaceTool, points: Array, normals: Array, color: Color) -> void:
	var a: Vector3 = points[0]
	var b: Vector3 = points[1]
	var c: Vector3 = points[2]
	var facing: Vector3 = normals[0] + normals[1] + normals[2]
	var order := [0, 1, 2]
	if (b - a).cross(c - a).dot(facing) > 0.0:
		order = [0, 2, 1]
	for i in order:
		tool.set_color(color)
		tool.set_normal(normals[i])
		tool.add_vertex(points[i])


func _in_hatch(s: int, r: int) -> bool:
	var ring := posmod(r - HATCH_RINGS.x, RING) + HATCH_RINGS.x
	return s >= HATCH_STATIONS.x and s < HATCH_STATIONS.y and ring >= HATCH_RINGS.x and ring < HATCH_RINGS.y


func _liner_point(t: float, u: float) -> Vector3:
	return _hull_point(t, u) - _hull_normal(t, u) * LINER


# Blocky 8-bit panelling: seams every few stations, a strip of ceiling lights,
# an orange accent stripe at waist height and dark glass behind the windows.
func _liner_color(s: int, r: int) -> Color:
	var t := (float(s) + 0.5) / STATIONS
	var u := (float(r) + 0.5) / RING
	var height := sin(u * TAU)
	if t > 0.66 and t < 0.77 and absf(cos(u * TAU)) < 0.62 and height > 0.5:
		return WINDOW_INSIDE
	if height > 0.97 and s % 5 < 3:
		return CEILING_LIGHT
	var y := _hull_point(t, u).y
	if y > 0.28 and y < 0.36:
		return ACCENT
	if s % 4 == 0:
		return SEAM
	return PANEL if (s / 2 + r / 2) % 2 == 0 else PANEL_DARK


# Flat plate closing the hull at the aft bulkhead.
func _aft_cap_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := Vector3(0.0, TOP_HEIGHT * 0.3, -LENGTH * 0.5)
	for r in range(RING):
		_triangle(tool, [centre, _hull_point(0.0, float(r + 1) / RING), _hull_point(0.0, float(r) / RING)], [Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD], Color.WHITE)
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
	# Scorching where the left wing tore away.
	if c > 0.55 and t < 0.42 and t > 0.1 and sin(u * TAU) < 0.55:
		return SCORCH.lerp(HULL_WHITE, 0.35 + 0.3 * absf(sin(float(station) * 1.7)))
	return TILE_SHADE if (station / 2 + ring_index / 2) % 2 == 0 else HULL_WHITE


func _half_width(t: float) -> float:
	return _hull_point(t, 0.0).x


# Height of the outer hull's upper surface at a given z and x, just below the
# skin, so parts mounted there stay out of the cabin.
func _roof_height(z: float, x: float) -> float:
	var t := _t_at(z)
	var along := clampf(absf(x) / _half_width(t), 0.0, 1.0)
	var theta := acos(pow(along, 1.0 / 0.75))
	return _hull_point(t, theta / TAU).y - 0.03


func _inner_half_width(t: float) -> float:
	return _half_width(t) - INNER_WALL_INSET


func _z_at(t: float) -> float:
	return lerpf(-LENGTH * 0.5, LENGTH * 0.5, t)


func _t_at(z: float) -> float:
	return z / LENGTH + 0.5


func _to_root(local: Vector3) -> Vector3:
	return model.transform * (body.transform * local)


func _world_to_body(world: Vector3) -> Vector3:
	return body.transform.affine_inverse() * (model.global_transform.affine_inverse() * world)


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
		_triangle(tool, [a, b, c], [normal, normal, normal], Color.WHITE)
		_triangle(tool, [a, c, d], [normal, normal, normal], Color.WHITE)
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


func _glow_material(color: Color) -> StandardMaterial3D:
	var material := _material(color, 0.4)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.4
	return material


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	# Procedural faces carry explicit outward normals; draw both sides so
	# winding order never hides a panel.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
