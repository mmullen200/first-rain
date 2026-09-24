extends Node3D

# THROWAWAY PROTOTYPE.
# The colony's hanging fungus garden: a spiral terraced tower the workers grow
# over the nest from chewed fibre and hoodoo matter. A ramp winds up around a
# twisted three-strand column; fungus beds sit on its terraces, strands of
# fungus hang from its edges and amber fruiting caps glow along it. It is open
# because the fungus needs air and shade, and it is only as tall as the garden
# is large: set_growth() reveals it from the ground up and takes it back down
# when the garden fails. Presentation only; the garden amount lives in the
# colony's authoritative state.

const SEED := 20260924
const HEIGHT := 3.4
const TURNS := 2.2
const BASE_RADIUS := 1.0
const TOP_RADIUS := 0.34
# Two ramps wind through each other like a double staircase, half a turn
# apart, each wobbling out of step with the other.
const RAMPS := 2
const SEGMENTS := 22
const SAMPLES_PER_SEGMENT := 4
const RAMP_WIDTH := 0.42
const RAMP_THICKNESS := 0.09

var segments: Array[Node3D] = []
var segment_heights: Array[float] = []
var column_strands: Array[MeshInstance3D] = []
var drapes: Array[MeshInstance3D] = []
var growth := 0.0
var shown_growth := 0.0
var sway_time := 0.0

var fibre_material: StandardMaterial3D
var bed_material: StandardMaterial3D
var drape_material: StandardMaterial3D
var cap_material: StandardMaterial3D


func _init() -> void:
	name = "GardenSpire"
	fibre_material = _material(Color("b38863"), 0.88)
	bed_material = _material(Color("7d4fc9"), 0.55, Color("6a3fd0"), 0.9)
	drape_material = _material(Color("c7b3ea"), 0.6, Color("8e6ad8"), 0.45)
	cap_material = _material(Color("f0b04d"), 0.4, Color("e08a2a"), 1.1)
	_build()
	set_growth(0.0)


# Fraction of the tower that stands, 0 (just the mound) to 1 (full spire).
func set_growth(fraction: float) -> void:
	growth = clampf(fraction, 0.0, 1.0)


func _process(delta: float) -> void:
	sway_time += delta
	# Growth and die-back show as the tower rising or sinking, not popping.
	shown_growth = move_toward(shown_growth, growth, delta * 0.08)
	_apply_growth()
	var pulse := 0.75 + 0.25 * sin(sway_time * 1.3)
	bed_material.emission_energy_multiplier = 0.9 * pulse * clampf(shown_growth * 3.0, 0.0, 1.0)
	cap_material.emission_energy_multiplier = 1.1 * (0.85 + 0.15 * sin(sway_time * 2.1 + 1.0))
	for index in range(drapes.size()):
		var drape := drapes[index]
		drape.rotation.z = sin(sway_time * 0.9 + float(index) * 0.7) * 0.07
		drape.rotation.x = cos(sway_time * 0.7 + float(index) * 1.3) * 0.05


func _apply_growth() -> void:
	var revealed := shown_growth * float(SEGMENTS)
	for index in range(segments.size()):
		var segment := segments[index]
		var amount := clampf(revealed - segment_heights[index] * float(SEGMENTS), 0.0, 1.0)
		segment.visible = amount > 0.0
		segment.scale = Vector3.ONE * lerpf(0.35, 1.0, amount)
	var column_height := clampf(shown_growth * 1.08, 0.04, 1.0)
	for strand in column_strands:
		strand.scale = Vector3(1.0, column_height, 1.0)


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	# The squat chewed-fibre mound the colony starts with.
	var mound := MeshInstance3D.new()
	var mound_mesh := SphereMesh.new()
	mound_mesh.radius = 0.55
	mound_mesh.height = 0.5
	mound.mesh = mound_mesh
	mound.scale = Vector3(1.0, 0.55, 1.0)
	mound.material_override = fibre_material
	add_child(mound)

	# Three strands twisting around each other up the middle.
	for strand_index in range(3):
		var points: Array[Vector3] = []
		for step in range(41):
			var t := float(step) / 40.0
			var angle := TAU * (float(strand_index) / 3.0) + t * TAU * 1.6
			var radius := lerpf(0.26, 0.07, t)
			points.append(Vector3(cos(angle) * radius, t * HEIGHT, sin(angle) * radius))
		var strand := MeshInstance3D.new()
		strand.mesh = _tube(points, 0.07, 0.028)
		strand.material_override = fibre_material
		add_child(strand)
		column_strands.append(strand)

	for ramp_index in range(RAMPS):
		for segment_index in range(SEGMENTS):
			_build_segment(rng, ramp_index, segment_index)


func _build_segment(rng: RandomNumberGenerator, ramp_index: int, segment_index: int) -> void:
	var segment := Node3D.new()
	segment.name = "Terrace_%d_%02d" % [ramp_index, segment_index]
	add_child(segment)
	segments.append(segment)
	var t0 := float(segment_index) / float(SEGMENTS)
	var t1 := float(segment_index + 1) / float(SEGMENTS)
	segment_heights.append(t0)
	var phase := PI * float(ramp_index)
	var centre := _ramp_point(lerpf(t0, t1, 0.5), phase)
	# Scale each piece about its own middle so it grows out of the ramp.
	segment.position = centre
	var ramp := MeshInstance3D.new()
	ramp.mesh = _ramp_mesh(t0, t1, centre, phase)
	ramp.material_override = fibre_material
	segment.add_child(ramp)

	# A rib back to the column keeps the ramp open to the air.
	if segment_index % 2 == 0:
		var hub := Vector3(0.0, centre.y - 0.18, 0.0) - centre
		var rib := MeshInstance3D.new()
		rib.mesh = _tube([Vector3(0.0, -0.02, 0.0), hub * 0.5 + Vector3(0.0, -0.08, 0.0), hub], 0.022, 0.012)
		rib.material_override = fibre_material
		segment.add_child(rib)

	# Fungus beds lie along the terrace top.
	var bed := MeshInstance3D.new()
	var bed_mesh := SphereMesh.new()
	bed_mesh.radius = RAMP_WIDTH * 0.4
	bed_mesh.height = 0.14
	bed.mesh = bed_mesh
	bed.position = Vector3(0.0, RAMP_THICKNESS * 0.6, 0.0)
	# Stretch each bed along the ramp so the terrace reads as one planting.
	bed.scale = Vector3(1.9, 0.5, 1.0)
	bed.rotation.y = -(_ramp_angle(lerpf(t0, t1, 0.5)) + phase + PI * 0.5)
	bed.material_override = bed_material
	segment.add_child(bed)

	# Strands of fungus hang from the outer edge: the hanging garden.
	var outward := Vector3(centre.x, 0.0, centre.z).normalized()
	for drape_index in range(rng.randi_range(2, 4)):
		var length := rng.randf_range(0.25, 0.85) * lerpf(1.25, 0.7, t0)
		var drape := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = rng.randf_range(0.018, 0.03)
		cone.bottom_radius = 0.003
		cone.height = length
		cone.radial_segments = 6
		drape.mesh = cone
		var along := rng.randf_range(-0.08, 0.08)
		var edge := outward * (RAMP_WIDTH * 0.5 + 0.01) + outward.cross(Vector3.UP) * along
		var pivot := Node3D.new()
		pivot.position = edge + Vector3(0.0, -RAMP_THICKNESS * 0.5, 0.0)
		segment.add_child(pivot)
		drape.position = Vector3(0.0, -length * 0.5, 0.0)
		drape.material_override = drape_material
		pivot.add_child(drape)
		drapes.append(pivot)

	# Amber fruiting caps on every few terraces, like lamps.
	if rng.randf() < 0.45:
		var cap := MeshInstance3D.new()
		var cap_mesh := SphereMesh.new()
		cap_mesh.radius = rng.randf_range(0.045, 0.075)
		cap_mesh.height = cap_mesh.radius * 1.1
		cap.mesh = cap_mesh
		cap.position = Vector3(0.0, RAMP_THICKNESS * 0.6 + 0.05, 0.0) + outward * rng.randf_range(-0.08, 0.06)
		cap.scale = Vector3(1.0, 0.6, 1.0)
		cap.material_override = cap_material
		segment.add_child(cap)
		var stalk := MeshInstance3D.new()
		var stalk_mesh := CylinderMesh.new()
		stalk_mesh.top_radius = 0.012
		stalk_mesh.bottom_radius = 0.018
		stalk_mesh.height = 0.06
		stalk.mesh = stalk_mesh
		stalk.position = cap.position + Vector3(0.0, -0.035, 0.0)
		stalk.material_override = drape_material
		segment.add_child(stalk)


# The ramp's centre line: a helix whose radius shrinks with height and
# wobbles, and which leans a little, so the tower reads as grown, not built.
func _ramp_point(t: float, phase: float) -> Vector3:
	var angle := _ramp_angle(t) + phase
	var radius := lerpf(BASE_RADIUS, TOP_RADIUS, pow(t, 0.8)) * (1.0 + 0.14 * sin(t * TAU * 3.0 + 0.6 + phase * 1.7))
	var lean := Vector3(0.16, 0.0, -0.08) * t * t
	var rise := 0.3 + t * (HEIGHT - 0.4) + phase / TAU * (HEIGHT / TURNS) * 0.5
	return Vector3(cos(angle) * radius, rise, sin(angle) * radius) + lean


func _ramp_angle(t: float) -> float:
	return t * TAU * TURNS


# A flat band swept along the helix between t0 and t1, in segment-local space.
func _ramp_mesh(t0: float, t1: float, origin: Vector3, phase: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for step in range(SAMPLES_PER_SEGMENT + 1):
		var t := lerpf(t0, t1, float(step) / float(SAMPLES_PER_SEGMENT))
		var centre := _ramp_point(t, phase) - origin
		var outward := Vector3(cos(_ramp_angle(t) + phase), 0.0, sin(_ramp_angle(t) + phase))
		var width := RAMP_WIDTH * lerpf(1.0, 0.65, t)
		var half := RAMP_THICKNESS * 0.5
		var outer := centre + outward * width * 0.5
		var inner := centre - outward * width * 0.5
		rings.append([inner + Vector3.UP * half, outer + Vector3.UP * half, outer - Vector3.UP * half, inner - Vector3.UP * half, outward])
	for step in range(rings.size() - 1):
		var a: Array = rings[step]
		var b: Array = rings[step + 1]
		_quad(tool, a[0], a[1], b[1], b[0], Vector3.UP)
		_quad(tool, a[3], a[2], b[2], b[3], Vector3.DOWN)
		_quad(tool, a[1], a[2], b[2], b[1], a[4])
		_quad(tool, a[0], a[3], b[3], b[0], -a[4])
	return tool.commit()


func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, facing: Vector3) -> void:
	var normal := (b - a).cross(d - a).normalized()
	if normal.dot(facing) < 0.0:
		normal = -normal
	for corner in [a, b, c, a, c, d]:
		tool.set_normal(normal)
		tool.add_vertex(corner)


# A tube swept along a polyline, tapering from start to end radius.
func _tube(points: Array, start_radius: float, end_radius: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 7
	var rings: Array = []
	for index in range(points.size()):
		var point: Vector3 = points[index]
		var ahead: Vector3 = points[mini(index + 1, points.size() - 1)]
		var behind: Vector3 = points[maxi(index - 1, 0)]
		var tangent := (ahead - behind).normalized()
		var side := tangent.cross(Vector3.UP)
		if side.length() < 0.01:
			side = tangent.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(tangent).normalized()
		var radius := lerpf(start_radius, end_radius, float(index) / float(maxi(1, points.size() - 1)))
		var ring: Array = []
		for corner in range(sides):
			var angle := TAU * float(corner) / float(sides)
			var direction := side * cos(angle) + up * sin(angle)
			ring.append([point + direction * radius, direction])
		rings.append(ring)
	for index in range(rings.size() - 1):
		for corner in range(sides):
			var next := (corner + 1) % sides
			for pick in [[index, corner], [index, next], [index + 1, next], [index, corner], [index + 1, next], [index + 1, corner]]:
				var vertex: Array = rings[pick[0]][pick[1]]
				tool.set_normal(vertex[1])
				tool.add_vertex(vertex[0])
	return tool.commit()


func _material(color: Color, roughness: float, emission := Color(0, 0, 0), energy := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material
