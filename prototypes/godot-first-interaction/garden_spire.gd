extends Node3D

# THROWAWAY PROTOTYPE.
# The colony's hanging fungus garden, grown like tree rings. Each terrace is
# laid from one record in the colony's authoritative state (see
# animal_simulation.gd, _grow_colony_terraces) and keeps the circumstances it
# was laid in:
#   heading       -> the terrace reaches out toward where the food came from
#   richness      -> plenty lays wide terraces with long hanging strands;
#                    lean times lay narrow, pinched ones
#   hoodoo_share  -> rust-coloured when the colony lived on hoodoo, pale
#                    green-tan when it lived on cut plants
#   damp_heading  -> the tower leans a little further toward the damp side
#   seed          -> small irregularities, so two similar lives still differ
# Two ramps wind through each other around a twisted three-strand column.
# Terraces are added and lost from the top, so a regrown tower comes back
# different. Presentation only.

const TERRACE_RISE := 0.23
const BASE_LIFT := 0.3
const BASE_RADIUS := 1.0
const TOP_RADIUS := 0.36
const MAX_TERRACES := 14
const RAMPS := 2
const SAMPLES := 8
const RAMP_THICKNESS := 0.08
const APPEAR_SECONDS := 3.0
const FALL_SECONDS := 2.0
const PLANT_FIBRE := Color("a39c6c")
const HOODOO_FIBRE := Color("b2623a")

var records: Array = []
var terrace_nodes: Array[Node3D] = []
var centres: Array[Vector3] = []
var start_angles: Array[float] = []
var spans: Array[float] = []
var falling: Array[Node3D] = []
var drapes: Array[Node3D] = []
var column: Node3D
var sway_time := 0.0

var bed_material: StandardMaterial3D
var drape_material: StandardMaterial3D
var cap_material: StandardMaterial3D
var mound_material: StandardMaterial3D


func _init() -> void:
	name = "GardenSpire"
	bed_material = _material(Color("7d4fc9"), 0.55, Color("6a3fd0"), 0.9)
	drape_material = _material(Color("c7b3ea"), 0.6, Color("8e6ad8"), 0.45)
	cap_material = _material(Color("f0b04d"), 0.4, Color("e08a2a"), 1.1)
	mound_material = _material(Color("a88a66"), 0.9)
	var mound := MeshInstance3D.new()
	var mound_mesh := SphereMesh.new()
	mound_mesh.radius = 0.55
	mound_mesh.height = 0.5
	mound.mesh = mound_mesh
	mound.scale = Vector3(1.0, 0.55, 1.0)
	mound.material_override = mound_material
	add_child(mound)
	column = Node3D.new()
	column.name = "Column"
	add_child(column)


# Height of the top of the standing terraces, for placing labels above it.
func top_height() -> float:
	return BASE_LIFT + float(terrace_nodes.size()) * TERRACE_RISE


# Terraces only ever change at the top, so keep the common prefix, drop what
# is gone, and grow what is new.
func set_terraces(new_records: Array) -> void:
	var keep := 0
	while keep < mini(records.size(), new_records.size()) and records[keep] == new_records[keep]:
		keep += 1
	if keep == records.size() and keep == new_records.size():
		return
	while terrace_nodes.size() > keep:
		var gone: Node3D = terrace_nodes.pop_back()
		gone.set_meta("fall", 0.0)
		falling.append(gone)
		centres.pop_back()
		start_angles.pop_back()
		spans.pop_back()
	records = new_records.duplicate(true)
	for index in range(keep, mini(records.size(), MAX_TERRACES)):
		_add_terrace(index, records[index])
	_rebuild_column()


func _process(delta: float) -> void:
	sway_time += delta
	for node in terrace_nodes:
		var age := float(node.get_meta("age", APPEAR_SECONDS)) + delta
		node.set_meta("age", age)
		node.scale = Vector3.ONE * lerpf(0.2, 1.0, clampf(age / APPEAR_SECONDS, 0.0, 1.0))
	for node in falling.duplicate():
		var fall := float(node.get_meta("fall")) + delta
		node.set_meta("fall", fall)
		node.scale = Vector3.ONE * maxf(0.01, 1.0 - fall / FALL_SECONDS)
		if fall >= FALL_SECONDS:
			falling.erase(node)
			node.queue_free()
	var pulse := 0.75 + 0.25 * sin(sway_time * 1.3)
	bed_material.emission_energy_multiplier = 0.9 * pulse
	cap_material.emission_energy_multiplier = 1.1 * (0.85 + 0.15 * sin(sway_time * 2.1 + 1.0))
	for index in range(drapes.size() - 1, -1, -1):
		var drape := drapes[index]
		if not is_instance_valid(drape) or drape.is_queued_for_deletion():
			drapes.remove_at(index)
			continue
		drape.rotation.z = sin(sway_time * 0.9 + float(index) * 0.7) * 0.07
		drape.rotation.x = cos(sway_time * 0.7 + float(index) * 1.3) * 0.05


func _add_terrace(index: int, record: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(record["seed"])
	var richness := float(record["richness"])
	var heading := float(record["heading"])
	var damp := float(record["damp_heading"])
	var previous_centre := centres[-1] if not centres.is_empty() else Vector3.ZERO
	var previous_angle := start_angles[-1] if not start_angles.is_empty() else rng.randf_range(0.0, TAU)
	var previous_span := spans[-1] if not spans.is_empty() else 0.0
	# The spine drifts toward the damp side and toward the food, so the tower
	# bends over its height the way the colony's life went.
	var drift := Vector3(cos(damp), 0.0, sin(damp)) * 0.035 + Vector3(cos(heading), 0.0, sin(heading)) * 0.025 * richness
	var centre := Vector3(previous_centre.x, BASE_LIFT + float(index) * TERRACE_RISE, previous_centre.z) + drift
	var start_angle := previous_angle + previous_span
	# Each terrace winds less than half a turn per ramp, leaving gaps so the two
	# ramps read as a spiral rather than stacked plates.
	var span := TAU * rng.randf_range(0.3, 0.45)
	centres.append(centre)
	start_angles.append(start_angle)
	spans.append(span)

	var node := Node3D.new()
	node.name = "Terrace_%02d" % index
	node.position = centre
	node.set_meta("age", 0.0)
	add_child(node)
	terrace_nodes.append(node)
	var fibre := _material(PLANT_FIBRE.lerp(HOODOO_FIBRE, float(record["hoodoo_share"])).darkened(rng.randf_range(0.0, 0.12)), 0.88)
	var height_fraction := float(index) / float(MAX_TERRACES - 1)
	var radius := lerpf(BASE_RADIUS, TOP_RADIUS, pow(height_fraction, 0.8)) * lerpf(0.6, 1.15, richness) * rng.randf_range(0.92, 1.08)
	var width := lerpf(0.16, 0.44, richness)
	for ramp in range(RAMPS):
		_add_arc(node, rng, start_angle + PI * float(ramp), span, radius, width, heading, richness, fibre)


# One ramp arc: a band rising one terrace as it winds, pushed further out on
# the side facing the food.
func _add_arc(node: Node3D, rng: RandomNumberGenerator, arc_start: float, span: float, radius: float, width: float, heading: float, richness: float, fibre: StandardMaterial3D) -> void:
	var points: Array = []
	for step in range(SAMPLES + 1):
		var f := float(step) / float(SAMPLES)
		var angle := arc_start + span * f
		var reach := radius * (1.0 + 0.35 * cos(angle - heading))
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		points.append([outward * reach + Vector3.UP * (f * TERRACE_RISE), outward, angle])
	var band := MeshInstance3D.new()
	band.mesh = _band_mesh(points, width)
	band.material_override = fibre
	node.add_child(band)

	# A rib back to the spine keeps the ramp open to the air.
	var mid: Array = points[SAMPLES / 2]
	var mid_point: Vector3 = mid[0]
	var rib := MeshInstance3D.new()
	rib.mesh = _tube([mid_point + Vector3.DOWN * 0.03, mid_point * 0.5 + Vector3.DOWN * 0.1, Vector3(0.0, -0.12, 0.0)], 0.022, 0.012)
	rib.material_override = fibre
	node.add_child(rib)

	var beds := 1 + roundi(3.0 * richness)
	for bed_index in range(beds):
		var at: Array = points[clampi(roundi((float(bed_index) + 0.5) / float(beds) * SAMPLES), 0, SAMPLES)]
		var bed := MeshInstance3D.new()
		var bed_mesh := SphereMesh.new()
		bed_mesh.radius = width * 0.42
		bed_mesh.height = 0.13
		bed.mesh = bed_mesh
		bed.position = Vector3(at[0]) + Vector3.UP * RAMP_THICKNESS * 0.6
		bed.scale = Vector3(1.7, 0.5, 1.0)
		bed.rotation.y = -(float(at[2]) + PI * 0.5)
		bed.material_override = bed_material
		node.add_child(bed)

	for drape_index in range(roundi(1.0 + 4.0 * richness)):
		var at: Array = points[rng.randi_range(0, SAMPLES)]
		var length := rng.randf_range(0.12, 0.2) + rng.randf_range(0.2, 0.65) * richness
		var pivot := Node3D.new()
		pivot.position = Vector3(at[0]) + Vector3(at[1]) * (width * 0.5 + 0.01) + Vector3.DOWN * RAMP_THICKNESS * 0.5
		node.add_child(pivot)
		var drape := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = rng.randf_range(0.016, 0.03)
		cone.bottom_radius = 0.003
		cone.height = length
		cone.radial_segments = 6
		drape.mesh = cone
		drape.position = Vector3(0.0, -length * 0.5, 0.0)
		drape.material_override = drape_material
		pivot.add_child(drape)
		drapes.append(pivot)

	if rng.randf() < 0.2 + 0.5 * richness:
		var at: Array = points[rng.randi_range(1, SAMPLES - 1)]
		var cap := MeshInstance3D.new()
		var cap_mesh := SphereMesh.new()
		cap_mesh.radius = rng.randf_range(0.045, 0.075)
		cap_mesh.height = cap_mesh.radius * 1.1
		cap.mesh = cap_mesh
		cap.position = Vector3(at[0]) + Vector3.UP * (RAMP_THICKNESS * 0.6 + 0.05)
		cap.scale = Vector3(1.0, 0.6, 1.0)
		cap.material_override = cap_material
		node.add_child(cap)


# Three strands twisting up through every terrace's centre.
func _rebuild_column() -> void:
	for child in column.get_children():
		child.queue_free()
	var path: Array[Vector3] = [Vector3.ZERO]
	for centre in centres:
		path.append(centre)
	if centres.is_empty():
		path.append(Vector3(0.0, BASE_LIFT, 0.0))
	path.append(path[-1] + Vector3.UP * TERRACE_RISE)
	var fibre := _material(Color("9a7a58"), 0.88)
	for strand_index in range(3):
		var points: Array[Vector3] = []
		var steps := (path.size() - 1) * 5
		for step in range(steps + 1):
			var f := float(step) / float(steps) * float(path.size() - 1)
			var low := mini(floori(f), path.size() - 2)
			var along: Vector3 = path[low].lerp(path[low + 1], f - float(low))
			var t := along.y / maxf(0.01, path[-1].y)
			var angle := TAU * float(strand_index) / 3.0 + t * TAU * 1.6
			var twist := lerpf(0.26, 0.07, t)
			points.append(along + Vector3(cos(angle), 0.0, sin(angle)) * twist)
		var strand := MeshInstance3D.new()
		strand.mesh = _tube(points, 0.07, 0.028)
		strand.material_override = fibre
		column.add_child(strand)


func _band_mesh(points: Array, width: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var half := RAMP_THICKNESS * 0.5
	for point in points:
		var centre: Vector3 = point[0]
		var outward: Vector3 = point[1]
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
