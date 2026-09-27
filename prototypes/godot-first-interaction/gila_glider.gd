extends Node3D

# THROWAWAY PROTOTYPE.
# The predator: a heavy, beaded lizard like a gila monster, black with salmon
# bands, with a thick fat-storing tail and small wings folded along its flanks.
# It cannot fly, only glide, and spreads its wings only while it glides in on a
# dust front or climbs back out. Faces +Z. Presentation only: the marker it
# rides on owns position and heading.
#
# The body is a chain of segments. The head leads and each segment follows the
# one ahead of it, so the body trails along the path the head took; a
# side-to-side wave runs back along the body and tail as it walks, paced by
# distance travelled, and the tail flicks slowly when it stands still. The
# sprawled legs step in diagonal pairs. Each wing is a row of strips with a
# ripple running out along the span, strong while gliding and faint when folded.

# [length to the segment ahead, parts]; a part is [radius, scale, offset,
# banded]. The first entry is the head.
const SEGMENTS := [
	[0.0, [[0.13, Vector3(1.1, 0.55, 1.35), Vector3.ZERO, false], [0.05, Vector3(1.2, 0.4, 1.0), Vector3(0.0, 0.06, 0.04), true]]],
	[0.2, [[0.2, Vector3(1.05, 0.42, 0.9), Vector3.ZERO, false], [0.09, Vector3(1.3, 0.35, 0.8), Vector3(-0.07, 0.07, 0.0), true]]],
	[0.18, [[0.2, Vector3(1.05, 0.42, 0.9), Vector3.ZERO, false], [0.08, Vector3(1.2, 0.35, 0.9), Vector3(0.08, 0.07, 0.02), true]]],
	[0.18, [[0.19, Vector3(1.0, 0.42, 0.9), Vector3.ZERO, false], [0.1, Vector3(1.4, 0.35, 0.7), Vector3(-0.03, 0.07, 0.0), true], [0.07, Vector3(1.0, 0.35, 0.8), Vector3(0.09, 0.06, -0.08), true]]],
	[0.2, [[0.16, Vector3(1.0, 0.6, 1.3), Vector3(0.0, -0.02, 0.0), false], [0.08, Vector3(1.5, 0.4, 0.7), Vector3(0.0, 0.05, 0.0), true]]],
	[0.2, [[0.12, Vector3(1.0, 0.6, 1.4), Vector3(0.0, -0.03, 0.0), false], [0.06, Vector3(1.5, 0.45, 0.8), Vector3(0.0, 0.02, 0.0), true]]],
	[0.18, [[0.08, Vector3(1.0, 0.6, 1.6), Vector3(0.0, -0.04, 0.0), false], [0.04, Vector3(1.5, 0.5, 0.9), Vector3(0.0, 0.0, 0.0), true]]],
	[0.15, [[0.05, Vector3(1.0, 0.6, 1.8), Vector3(0.0, -0.05, 0.0), false]]],
	[0.12, [[0.035, Vector3(1.0, 0.6, 1.8), Vector3(0.0, -0.05, 0.0), false]]],
]
const HEAD_OFFSET := 0.42
const FRONT_LEGS := 1
const HIND_LEGS := 3
const WING_SEGMENT := 1
const WING_STRIPS := 6
const STRIP_SPAN := 0.085
const WAVE_PER_METRE := 5.5
const WAVE_SPACING := 0.8
const SWAY := 0.075

var segments: Array[Node3D] = []
var points: Array[Vector3] = []
var legs: Array[Node3D] = []
var wing_roots: Array[Node3D] = []
var spread := 0.0
var phase := 0.0
var time := 0.0
var walk := 0.0
var placed := false
var last_head := Vector3.ZERO
var dark: StandardMaterial3D
var band: StandardMaterial3D
var membrane: StandardMaterial3D


func _init(band_color: Color) -> void:
	name = "Lizard"
	dark = _material(Color("201a18"), 0.9)
	band = _material(band_color.lerp(Color("e07a5c"), 0.6), 0.85, Color("4a1a10"))
	membrane = _material(Color("5e2b22"), 0.8, Color("2a0c08"))
	var z := HEAD_OFFSET
	for index in range(SEGMENTS.size()):
		var segment := Node3D.new()
		segment.name = "Head" if index == 0 else "Segment%d" % index
		z -= float(SEGMENTS[index][0])
		segment.position = Vector3(0.0, 0.0, z)
		for part in SEGMENTS[index][1]:
			_sphere(segment, part[0], part[1], part[2], band if part[3] else dark)
		add_child(segment)
		segments.append(segment)
	for index in [FRONT_LEGS, HIND_LEGS]:
		for side in [-1.0, 1.0]:
			# Sprawled legs, splayed out from the flanks.
			var hip := Node3D.new()
			hip.position = Vector3(side * 0.18, -0.08, 0.0)
			hip.set_meta("side", side)
			hip.set_meta("diagonal", side * (1.0 if index == FRONT_LEGS else -1.0))
			segments[index].add_child(hip)
			_sphere(hip, 0.06, Vector3(2.0, 0.6, 0.9), Vector3(side * 0.07, 0.0, 0.0), dark)
			_sphere(hip, 0.04, Vector3(1.2, 0.5, 1.4), Vector3(side * 0.18, -0.04, 0.03), dark)
			legs.append(hip)
	for side in [-1.0, 1.0]:
		var root := Node3D.new()
		root.name = "Wing%s" % ("Left" if side > 0.0 else "Right")
		root.position = Vector3(side * 0.12, 0.08, 0.0)
		root.set_meta("side", side)
		segments[WING_SEGMENT].add_child(root)
		# Each strip hangs off the one inboard of it, so bending every strip a
		# little adds up to a wave travelling out to the wingtip.
		var parent := root
		for strip in range(WING_STRIPS):
			var joint := Node3D.new()
			joint.position = Vector3(side * (0.0 if strip == 0 else STRIP_SPAN), 0.0, 0.0)
			parent.add_child(joint)
			# Flat, slightly overlapping panels read as one continuous membrane,
			# narrowing and sweeping back toward the tip.
			var taper := 1.0 - float(strip) / WING_STRIPS * 0.6
			var panel := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(STRIP_SPAN * 1.15, 0.012, 0.3 * taper)
			panel.mesh = box
			panel.position = Vector3(side * STRIP_SPAN * 0.5, 0.0, -0.025 * strip)
			panel.material_override = membrane
			joint.add_child(panel)
			parent = joint
		wing_roots.append(root)
	set_wing_spread(0.0)


# 0 folds the wings flat along the back; 1 spreads them out sideways to glide.
func set_wing_spread(value: float) -> void:
	spread = clampf(value, 0.0, 1.0)


func animate(delta: float) -> void:
	if delta <= 0.0 or not is_inside_tree():
		return
	time += delta
	var head := global_transform * Vector3(0.0, 0.0, HEAD_OFFSET)
	if not placed:
		_lay_out_straight()
		last_head = head
		placed = true
	var travelled := head.distance_to(last_head)
	last_head = head
	var target_walk := clampf(travelled / delta / 0.9, 0.0, 1.0) * (1.0 - spread)
	walk = lerpf(walk, target_walk, clampf(delta * 6.0, 0.0, 1.0))
	phase += travelled * WAVE_PER_METRE + delta * 0.9
	_follow_head(head)
	_pose_segments()
	_pose_legs()
	_pose_wings()


# Each point follows the one ahead at a fixed distance, like a rope pulled by
# its end, so the body swings wide on turns and straightens as it goes on.
func _follow_head(head: Vector3) -> void:
	points[0] = head
	for index in range(1, points.size()):
		var gap := float(SEGMENTS[index][0])
		var away := points[index] - points[index - 1]
		if away.length() < 0.0001:
			away = -global_basis.z
		points[index] = points[index - 1] + away.normalized() * gap


func _pose_segments() -> void:
	var inverse := global_transform.affine_inverse()
	var up := global_basis.y.normalized()
	for index in range(segments.size()):
		var ahead: Vector3 = points[maxi(index - 1, 0)]
		var behind: Vector3 = points[mini(index + 1, points.size() - 1)]
		var forward := (ahead - behind).normalized() if ahead.distance_to(behind) > 0.0001 else global_basis.z.normalized()
		var side := up.cross(forward).normalized()
		# The wave grows toward the tail; the head stays nearly steady.
		var reach := float(index) / (segments.size() - 1)
		var amplitude := SWAY * (0.25 + reach * 1.6) * (0.35 + 0.65 * walk)
		var sway := sin(phase - index * WAVE_SPACING) * amplitude
		var bend := cos(phase - index * WAVE_SPACING) * amplitude * 2.2
		var world := points[index] + side * sway
		var facing := (forward + side * bend).normalized()
		var local_position := inverse * world
		var local_forward := (inverse.basis * facing).normalized()
		var local_up := (inverse.basis * up).normalized()
		segments[index].transform = Transform3D(Basis.looking_at(-local_forward, local_up), local_position)


# Diagonal pairs step together, as a sprawling lizard walks; gliding tucks
# the legs back along the body.
func _pose_legs() -> void:
	for hip in legs:
		var side: float = hip.get_meta("side")
		var stride := sin(phase + (0.0 if float(hip.get_meta("diagonal")) > 0.0 else PI)) * 0.55 * walk
		hip.rotation = Vector3(0.0, side * stride + side * 0.9 * spread, -side * 0.15 * spread)


func _pose_wings() -> void:
	# Every strip bends a little, so the bend adds up toward the tip; keep each
	# step small or the wing curls up instead of rippling.
	var ripple := lerpf(0.015, 0.11, spread)
	var speed := lerpf(4.0, 7.0, spread)
	for root in wing_roots:
		var side: float = root.get_meta("side")
		# Folded, the wing lies back along the flank; spread, it reaches out.
		root.rotation = Vector3(0.0, side * lerpf(1.4, 0.0, spread), side * lerpf(0.12, 0.08, spread))
		root.scale = Vector3.ONE * lerpf(0.55, 1.3, spread)
		var joint: Node3D = root.get_child(0)
		var strip := 0
		while joint != null:
			joint.rotation.z = side * ripple * sin(time * speed - strip * 0.9)
			joint.rotation.x = 0.3 * ripple * spread * sin(time * speed * 0.7 - strip * 0.7)
			strip += 1
			joint = joint.get_child(1) if joint.get_child_count() > 1 else null


func _lay_out_straight() -> void:
	points.clear()
	var z := HEAD_OFFSET
	for index in range(SEGMENTS.size()):
		z -= float(SEGMENTS[index][0])
		points.append(global_transform * Vector3(0.0, 0.0, z))


func _sphere(parent: Node3D, radius: float, scale_value: Vector3, offset: Vector3, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	piece.mesh = mesh
	piece.scale = scale_value
	piece.position = offset
	piece.material_override = material
	parent.add_child(piece)
	return piece


func _material(color: Color, roughness: float, emission := Color(0.0, 0.0, 0.0, 1.0)) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission != Color(0.0, 0.0, 0.0, 1.0):
		material.emission_enabled = true
		material.emission = emission
	return material
