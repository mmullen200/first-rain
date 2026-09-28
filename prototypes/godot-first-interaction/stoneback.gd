extends Node3D

# THROWAWAY PROTOTYPE.
# The grazer, a stoneback: a low, broad animal under a domed back of
# overlapping stone-grey plates, like a woodlouse crossed with a tortoise.
# From above, where its gliding predator hunts, it looks like a rock; the
# luminous teal of its flanks and belly shows only when it lifts itself up to
# walk. Fine grooves run down the plates, wicking water to its mouth. An amber
# head sits under the front plate, with two short eye stalks turned to the sky
# and a rasping mouth underneath. Six short legs step in a ripple running
# from the back pair to the front. Faces +Z with its feet at y = 0.
# Presentation only: the marker it rides on owns position and heading.
#
# The gait is paced by distance travelled, so the feet do not skate. Walking
# lifts the shell clear of the ground; fleeing lifts it higher, lengthens the
# stride and lays the eye stalks back; feeding lowers it nose-down over the
# forage and rasps; resting settles it almost flat, breathing slowly while the
# eye stalks scan. A juvenile is smaller and its plates have not hardened, so
# its teal shows through even at rest.

# [z, half width, height, length] of each band of plates, front to back.
const BANDS := [
	[0.25, 0.25, 0.2, 0.15],
	[0.14, 0.31, 0.25, 0.16],
	[0.02, 0.33, 0.27, 0.16],
	[-0.1, 0.32, 0.25, 0.16],
	[-0.21, 0.28, 0.21, 0.15],
	[-0.3, 0.2, 0.15, 0.12],
]
# [z, pair] of each leg pair's hip, front to back.
const LEG_PAIRS := [0.2, 0.0, -0.19]
const HIP_WIDTH := 0.2
const FOOT_WIDTH := 0.33
const STEP_HEIGHT := 0.055
const REST_LIFT := 0.03
const WALK_LIFT := 0.1
const FLEE_LIFT := 0.14
const FEED_LIFT := 0.05

var juvenile := false
var body: Node3D
var head: Node3D
var stalks: Array[Node3D] = []
var legs: Array[Node3D] = []
var plates: Array[MeshInstance3D] = []
var phase := 0.0
var time := 0.0
var walk := 0.0
var lift := REST_LIFT
var pitch := 0.0
var rasp := 0.0
var alert := 0.0
var placed := false
var last_position := Vector3.ZERO
var shell_material: StandardMaterial3D
var seam_material: StandardMaterial3D
var flank_material: StandardMaterial3D
var head_material: StandardMaterial3D
var dark_material: StandardMaterial3D
var eye_material: StandardMaterial3D


func _init(is_juvenile := false) -> void:
	name = "Stoneback"
	shell_material = _material(Color("6c6b63"), 0.96)
	seam_material = _material(Color("636159"), 0.98)
	flank_material = _material(Color("76d2bd"), 0.55, Color("237563"))
	head_material = _material(Color("f2c36d"), 0.5, Color("8f571c"))
	dark_material = _material(Color("2d2a26"), 0.8)
	eye_material = _material(Color("15181a"), 0.15, Color("1d3b36"))

	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	# The glowing flank and belly, tucked under the rim of the shell.
	_sphere(body, 0.3, Vector3(0.95, 0.32, 1.3), Vector3(0.0, 0.05, -0.01), flank_material)

	for index in BANDS.size():
		var band: Array = BANDS[index]
		# Each band overlaps the one behind it and tips back a little, so the
		# plate edges catch the light like a woodlouse's back.
		var plate := _sphere(body, 0.5, Vector3(band[1] * 2.0, band[2] * 2.0, band[3] * 2.0), Vector3(0.0, 0.04, band[0]), shell_material if index % 2 == 0 else seam_material)
		plate.mesh.is_hemisphere = true
		plate.rotation.x = -0.18
		plate.name = "Plate%d" % index
		plates.append(plate)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 0.06, 0.37)
	body.add_child(head)
	_sphere(head, 0.11, Vector3(1.25, 0.7, 1.0), Vector3.ZERO, head_material)
	# The rasping mouth, a dark pad underneath.
	_sphere(head, 0.05, Vector3(1.3, 0.35, 0.9), Vector3(0.0, -0.06, 0.04), dark_material)
	for side in [-1.0, 1.0]:
		var stalk := Node3D.new()
		stalk.name = "EyeStalk%s" % ("Left" if side > 0.0 else "Right")
		stalk.position = Vector3(side * 0.055, 0.05, 0.05)
		stalk.set_meta("side", side)
		head.add_child(stalk)
		var column := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.011
		cylinder.bottom_radius = 0.017
		cylinder.height = 0.22
		cylinder.radial_segments = 8
		column.mesh = cylinder
		column.position.y = 0.11
		column.material_override = head_material
		stalk.add_child(column)
		_sphere(stalk, 0.03, Vector3.ONE, Vector3(0.0, 0.225, 0.0), eye_material)
		stalks.append(stalk)

	for pair in LEG_PAIRS.size():
		for side in [-1.0, 1.0]:
			# Thigh and shin, each a unit-long limb pointed at its end and
			# stretched to it every frame.
			var leg := Node3D.new()
			leg.set_meta("side", side)
			leg.set_meta("pair", pair)
			add_child(leg)
			leg.add_child(_limb(0.028))
			leg.add_child(_limb(0.022))
			legs.append(leg)
	set_juvenile(is_juvenile)


func set_juvenile(value: bool) -> void:
	juvenile = value
	scale = Vector3.ONE * (0.62 if juvenile else 1.0)
	# Soft young plates let the glow through.
	shell_material.albedo_color = Color("8fb5aa") if juvenile else Color("6c6b63")
	shell_material.emission_enabled = juvenile
	shell_material.emission = Color("1f5a4d")


# `state` is the grazer's simulation state; only how the body carries itself
# depends on it. Movement comes from the marker.
func animate(delta: float, state: String) -> void:
	if delta <= 0.0 or not is_inside_tree():
		return
	time += delta
	var here := global_position
	if not placed:
		last_position = here
		placed = true
	var travelled := Vector2(here.x - last_position.x, here.z - last_position.z).length() / maxf(scale.x, 0.01)
	last_position = here
	var fleeing := state == "fleeing"
	var feeding := state == "feeding"
	var moving := clampf(travelled / delta / 0.3, 0.0, 1.0)
	walk = lerpf(walk, moving, clampf(delta * 5.0, 0.0, 1.0))
	alert = lerpf(alert, 1.0 if fleeing else 0.0, clampf(delta * 4.0, 0.0, 1.0))

	var target_lift := REST_LIFT
	if walk > 0.15:
		target_lift = lerpf(WALK_LIFT, FLEE_LIFT, alert)
	elif feeding:
		target_lift = FEED_LIFT
	lift = lerpf(lift, target_lift, clampf(delta * 3.0, 0.0, 1.0))
	pitch = lerpf(pitch, 0.16 if feeding and walk < 0.3 else (0.07 * alert), clampf(delta * 3.0, 0.0, 1.0))
	rasp = lerpf(rasp, 1.0 if feeding and walk < 0.3 else 0.0, clampf(delta * 4.0, 0.0, 1.0))

	# A planted foot sweeps `stride` either side of its hip over half a cycle,
	# so the body covers four strides in one full step cycle.
	var stride := lerpf(0.06, 0.1, alert)
	phase += travelled / (4.0 * stride) * TAU

	var breathing := sin(time * 2.4) * 0.006 * (1.0 - walk)
	# Three pairs in a ripple give a small bob three times a cycle.
	var bob := absf(sin(phase * 1.5)) * 0.012 * walk
	var sway := sin(phase) * 0.03 * walk
	var chew := sin(time * 16.0) * rasp
	body.position = Vector3(0.0, lift + breathing + bob + absf(chew) * 0.006, chew * 0.008)
	body.rotation = Vector3(pitch + chew * 0.02, sway * 0.4, sway * 0.5)
	head.rotation.x = 0.35 * rasp + chew * 0.08
	head.position.y = 0.06 - 0.03 * rasp

	_pose_legs(stride)
	_pose_stalks()


func _pose_legs(stride: float) -> void:
	var body_transform := body.transform
	for leg in legs:
		var side: float = leg.get_meta("side")
		var pair: int = leg.get_meta("pair")
		# The ripple runs from the back pair forward; the two sides alternate.
		var leg_phase := phase + float(pair) * TAU / 3.0 + (PI if side > 0.0 else 0.0)
		var hip := body_transform * Vector3(side * HIP_WIDTH, 0.03, LEG_PAIRS[pair])
		# Half the cycle planted, sweeping back at exactly the body's speed so the
		# foot holds its place on the ground; the other half lifted and swung
		# forward again.
		var cycle := fposmod(leg_phase, TAU) / TAU
		var swing: float
		var raised := 0.0
		if cycle < 0.5:
			swing = stride * (1.0 - 4.0 * cycle)
		else:
			var through := (cycle - 0.5) * 2.0
			swing = -stride + 2.0 * stride * smoothstep(0.0, 1.0, through)
			raised = sin(PI * through) * STEP_HEIGHT
		swing *= walk
		raised *= walk
		# Resting, the feet tuck in under the rim.
		var reach := lerpf(FOOT_WIDTH * 0.8, FOOT_WIDTH, clampf(lift / WALK_LIFT, 0.0, 1.0))
		var foot := Vector3(side * reach, raised, LEG_PAIRS[pair] + swing)
		# The knee rises up and out between hip and foot, higher when the leg
		# is tucked in under the rim.
		var knee := (hip + foot) * 0.5 + Vector3(side * 0.05, 0.07 + 0.04 * (1.0 - walk), 0.0)
		_point_limb(leg.get_child(0), hip, knee)
		_point_limb(leg.get_child(1), knee, foot)


# The eye stalks keep turning over the sky, each on its own slow rhythm; fleeing
# lays them back along the head.
func _pose_stalks() -> void:
	for stalk in stalks:
		var side: float = stalk.get_meta("side")
		var look := sin(time * 0.7 + side * 1.3) * 0.5 + sin(time * 1.9 + side) * 0.2
		var tilt := 0.2 + 0.2 * sin(time * 0.45 + side * 2.0)
		stalk.rotation = Vector3(lerpf(tilt, -1.3, alert) + 0.4 * rasp, look * (1.0 - alert), -side * lerpf(0.3, 0.1, alert))


func _limb(radius: float) -> Node3D:
	var joint := Node3D.new()
	var limb := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = 1.0
	capsule.radial_segments = 8
	capsule.rings = 2
	limb.mesh = capsule
	limb.rotation.x = PI * 0.5
	limb.position.z = -0.5
	limb.material_override = flank_material
	joint.add_child(limb)
	return joint


func _point_limb(joint: Node3D, from: Vector3, to: Vector3) -> void:
	var span := to - from
	var direction := span.normalized()
	joint.transform = Transform3D(Basis.looking_at(direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.FORWARD) * Basis.from_scale(Vector3(1.0, 1.0, span.length())), from)


func _sphere(parent: Node3D, radius: float, scale_value: Vector3, offset: Vector3, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
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
