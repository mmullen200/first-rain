extends Node3D

# THROWAWAY PROTOTYPE.
# The grazer, drawn after a Nigersaurus-like ground browser (user reference,
# 2026-09-28): a light four-legged body, a long neck carried permanently low,
# and a wide, flat, square muzzle lined with rows of small teeth, built to
# mow the ground layer rather than reach up. A crest of small amber spines
# runs down the neck, and a line of teal glow spots along each flank keeps the
# grazer's luminous colouring. About 0.7 m at the hips and 1.9 m from muzzle
# to tail tip, so it is prey-sized beside the gliding lizard. Faces +Z with
# its feet at y = 0. Presentation only: the marker it rides on owns position,
# heading and state.
#
# It walks in the four-beat sequence of a heavy quadruped (left hind, left
# fore, right hind, right fore), with three feet on the ground at a time. A
# planted foot sweeps back at the body's own speed, so it holds its place on
# the ground. The neck and tail are jointed chains: they sway with the gait,
# the head leads into turns and the tail lags behind them. Feeding drops the
# muzzle to the ground and sweeps it side to side while the jaw works;
# fleeing stretches the neck out ahead, lifts the tail and pulls in the
# tentacles; resting lets the head hang at mid-height, breathing, looking
# slowly about. In a herd (#51) a resting grazer sinks down onto folded legs
# and the lookout stands with its neck raised, scanning widely. Two long slug-like eye tentacles point forward and up in a V
# and two short feelers reach down toward the ground, each moving on its own.

const HIND_HIP := Vector3(0.14, 0.56, -0.24)
const FORE_HIP := Vector3(0.13, 0.5, 0.21)
const FOOT_SPREAD := 0.17
# Left hind, left fore, right hind, right fore: each leg's share of the cycle.
const LEG_ORDER := [[-1.0, true, 0.0], [-1.0, false, 0.25], [1.0, true, 0.5], [1.0, false, 0.75]]
const DUTY := 0.72
const STEP_HEIGHT := 0.09
const NECK_SEGMENTS := 6
const NECK_LENGTH := 0.12
const TAIL_SEGMENTS := 7
const TAIL_LENGTH := 0.12
# Slug-like tentacles (user, 2026-09-28 and 2026-09-30): [length, radius, x,
# y, z, splay, lean]. The long upper pair carries the eyes and points forward
# and up, splaying apart in a V; the short lower pair reaches forward and down
# to feel the ground. Lean tips a stalk forward from vertical and splay tips it
# outward, both in radians.
const TENTACLES := [[0.34, 0.02, 0.05, 0.08, 0.07, 0.32, 0.72], [0.12, 0.015, 0.1, -0.01, 0.2, 0.5, 1.75]]
const TENTACLE_JOINTS := 4
const BELLY_SCALE := Vector3(0.38, 0.26, 0.66)

var juvenile := false
var male := false
# 0 to 1 through a pregnancy; swells the belly.
var pregnancy := 0.0
var belly_mesh: MeshInstance3D
var body: Node3D
var neck: Array[Node3D] = []
var head: Node3D
var jaw: Node3D
var tail: Array[Node3D] = []
var legs: Array[Node3D] = []
var feet: Array[MeshInstance3D] = []
var spines: Array[MeshInstance3D] = []
var tentacles: Array[Node3D] = []
var phase := 0.0
var time := 0.0
var walk := 0.0
var alert := 0.0
var feeding := 0.0
var resting := 0.0
var watching := 0.0
var turn := 0.0
var placed := false
var last_position := Vector3.ZERO
var last_heading := 0.0
var skin: StandardMaterial3D
var belly: StandardMaterial3D
var spine_material: StandardMaterial3D
var glow: StandardMaterial3D
var tooth: StandardMaterial3D
var mouth: StandardMaterial3D
var eye: StandardMaterial3D


func _init(is_juvenile := false) -> void:
	name = "GrazerFigure"
	skin = _material(Color("8d9483"), 0.9)
	belly = _material(Color("d6ccb0"), 0.9)
	spine_material = _material(Color("c98d4a"), 0.7, Color("3a2008"))
	glow = _material(Color("76d2bd"), 0.5, Color("2a8c76"))
	tooth = _material(Color("efe8d6"), 0.4)
	mouth = _material(Color("b5594a"), 0.7)
	eye = _material(Color("15181a"), 0.2)

	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	# A light barrel of a body, hips higher than shoulders.
	var torso := _sphere(body, 0.5, Vector3(0.46, 0.44, 0.86), Vector3(0.0, 0.56, -0.02), skin)
	torso.rotation.x = 0.1
	belly_mesh = _sphere(body, 0.5, BELLY_SCALE, Vector3(0.0, 0.45, 0.0), belly)
	_sphere(body, 0.5, Vector3(0.34, 0.34, 0.34), Vector3(0.0, 0.6, -0.26), skin)
	_sphere(body, 0.5, Vector3(0.34, 0.32, 0.32), Vector3(0.0, 0.52, 0.25), skin)
	for side in [-1.0, 1.0]:
		for spot in 5:
			var z := 0.22 - 0.11 * spot
			_sphere(body, 0.024, Vector3(1.0, 1.0, 1.4), Vector3(side * (0.225 - absf(z) * 0.1), 0.57 + 0.02 * sin(spot * 1.7), z), glow)

	# The neck: a chain of joints, each hanging off the one before it.
	var parent: Node3D = body
	var joint_position := Vector3(0.0, 0.56, 0.38)
	for index in NECK_SEGMENTS:
		var joint := Node3D.new()
		joint.name = "Neck%d" % index
		joint.position = joint_position
		parent.add_child(joint)
		var radius := lerpf(0.125, 0.07, float(index) / NECK_SEGMENTS)
		_sphere(joint, radius, Vector3(1.0, 1.05, 1.5), Vector3(0.0, 0.0, NECK_LENGTH * 0.5), skin)
		_sphere(joint, radius * 0.8, Vector3(0.9, 0.7, 1.4), Vector3(0.0, -radius * 0.35, NECK_LENGTH * 0.5), belly)
		for crest in 2:
			var spine := _cone(joint, 0.012, 0.05 + 0.015 * (1 - index % 2), spine_material)
			spine.position = Vector3(0.0, radius * 0.95, NECK_LENGTH * (0.25 + 0.5 * crest))
			spine.rotation.x = -0.45
			spines.append(spine)
		neck.append(joint)
		parent = joint
		joint_position = Vector3(0.0, 0.0, NECK_LENGTH)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 0.0, NECK_LENGTH)
	parent.add_child(head)
	_sphere(head, 0.5, Vector3(0.17, 0.15, 0.22), Vector3(0.0, 0.02, 0.06), skin)
	# The square muzzle, much wider than the skull behind it.
	_sphere(head, 0.5, Vector3(0.32, 0.1, 0.17), Vector3(0.0, 0.0, 0.19), skin)
	for side in [-1.0, 1.0]:
		_sphere(head, 0.01, Vector3.ONE, Vector3(side * 0.05, 0.045, 0.25), eye)
		for pair in TENTACLES.size():
			tentacles.append(_tentacle(side, pair))
	_tooth_row(head, Vector3(0.0, -0.04, 0.27), -1.0)
	jaw = Node3D.new()
	jaw.name = "Jaw"
	jaw.position = Vector3(0.0, -0.04, 0.09)
	head.add_child(jaw)
	_sphere(jaw, 0.5, Vector3(0.3, 0.06, 0.2), Vector3(0.0, -0.015, 0.1), mouth)
	_sphere(jaw, 0.5, Vector3(0.31, 0.05, 0.19), Vector3(0.0, -0.03, 0.1), skin)
	_tooth_row(jaw, Vector3(0.0, 0.006, 0.185), 1.0)

	parent = body
	joint_position = Vector3(0.0, 0.6, -0.42)
	for index in TAIL_SEGMENTS:
		var joint := Node3D.new()
		joint.name = "Tail%d" % index
		joint.position = joint_position
		parent.add_child(joint)
		var radius := lerpf(0.12, 0.025, float(index) / (TAIL_SEGMENTS - 1))
		_sphere(joint, radius, Vector3(1.0, 1.0, 1.6), Vector3(0.0, 0.0, -TAIL_LENGTH * 0.5), skin)
		tail.append(joint)
		parent = joint
		joint_position = Vector3(0.0, 0.0, -TAIL_LENGTH)

	for entry in LEG_ORDER:
		var side: float = entry[0]
		var hind: bool = entry[1]
		var leg := Node3D.new()
		leg.set_meta("side", side)
		leg.set_meta("hind", hind)
		leg.set_meta("offset", entry[2])
		add_child(leg)
		leg.add_child(_limb(0.1 if hind else 0.085))
		leg.add_child(_limb(0.075 if hind else 0.07))
		var foot := _sphere(self, 0.09 if hind else 0.08, Vector3(1.0, 0.45, 1.1), Vector3.ZERO, skin)
		legs.append(leg)
		feet.append(foot)
	set_juvenile(is_juvenile)


func set_juvenile(value: bool) -> void:
	juvenile = value
	_show_sex()


# Males (#51) are a little bigger and carry a tall, bright orange crest down the
# neck; females have a low, dull crest. Juveniles of both are small and plain.
func set_male(value: bool) -> void:
	male = value
	_show_sex()


func _show_sex() -> void:
	scale = Vector3.ONE * (0.58 if juvenile else (1.08 if male else 1.0))
	skin.albedo_color = Color("a3ad98") if juvenile else (Color("858c7a") if male else Color("939a88"))
	spine_material.albedo_color = Color("e5782c") if male and not juvenile else Color("c98d4a")
	spine_material.emission = Color("6a2a04") if male and not juvenile else Color("3a2008")
	for spine in spines:
		var height := 0.5 if juvenile else (3.2 if male else 0.7)
		var width := 0.5 if juvenile else (2.4 if male else 1.0)
		spine.scale = Vector3(width, height, width)


# A pregnant female's belly swells out and down as the calf grows.
func set_pregnancy(progress: float) -> void:
	pregnancy = clampf(progress, 0.0, 1.0)
	var swell := pregnancy * pregnancy
	belly_mesh.scale = BELLY_SCALE * Vector3(1.0 + 0.55 * swell, 1.0 + 0.8 * swell, 1.0 + 0.15 * swell)
	belly_mesh.position.y = 0.45 - 0.07 * swell


# `state` is the grazer's simulation state; only how the body carries itself
# depends on it. Movement comes from the marker.
func animate(delta: float, state: String) -> void:
	if delta <= 0.0 or not is_inside_tree():
		return
	time += delta
	var here := global_position
	var heading := global_rotation.y
	if not placed:
		last_position = here
		last_heading = heading
		placed = true
	var travelled := Vector2(here.x - last_position.x, here.z - last_position.z).length() / maxf(scale.x, 0.01)
	var turning := wrapf(heading - last_heading, -PI, PI) / delta
	last_position = here
	last_heading = heading
	var blend := clampf(delta * 4.0, 0.0, 1.0)
	walk = lerpf(walk, clampf(travelled / delta / 0.25, 0.0, 1.0), clampf(delta * 5.0, 0.0, 1.0))
	alert = lerpf(alert, 1.0 if state == "fleeing" else 0.0, blend)
	feeding = lerpf(feeding, 1.0 if state in ["feeding", "grazing"] and walk < 0.3 else 0.0, clampf(delta * 2.5, 0.0, 1.0))
	# Herd poses (#51): a resting grazer sinks down onto folded legs; the
	# lookout stands tall with its neck raised and eye stalks spread.
	resting = lerpf(resting, 1.0 if state == "resting" and walk < 0.2 else 0.0, clampf(delta * 0.8, 0.0, 1.0))
	watching = lerpf(watching, 1.0 if state == "watching" else 0.0, clampf(delta * 1.5, 0.0, 1.0))
	turn = lerpf(turn, clampf(turning, -2.5, 2.5), blend)

	# A planted foot sweeps `stride` either side of its hip over the planted
	# share of the cycle, so the body covers 2 * stride / DUTY per cycle.
	var stride := lerpf(0.09, 0.16, alert)
	phase += travelled / (2.0 * stride / DUTY) * TAU

	var breathing := sin(time * 1.9) * 0.006 * (1.0 - walk)
	var bob := -absf(sin(phase * 2.0)) * 0.014 * walk
	body.position = Vector3(0.0, breathing + bob - 0.03 * feeding - 0.3 * resting, 0.0)
	body.rotation = Vector3(0.05 * feeding - 0.04 * alert, 0.0, sin(phase) * 0.03 * walk)

	_pose_neck()
	_pose_tentacles()
	_pose_tail()
	_pose_legs(stride)


# The neck starts up and forward from the shoulders and bends down along its
# length; how far it bends sets where the head is carried.
func _pose_neck() -> void:
	# `drop` tips the neck down at the shoulders; `bend` curves it along its
	# length. Mostly a straight slope, so the head rides near the ground.
	var drop := lerpf(lerpf(0.02, 0.1, walk), 0.04, feeding)
	var bend := lerpf(0.35, 0.5, feeding)
	drop = lerpf(drop, 0.02, alert)
	bend = lerpf(bend, 0.15, alert)
	drop = lerpf(drop, -0.35, watching)
	bend = lerpf(bend, 0.3, watching)
	drop = lerpf(drop, 0.0, resting)
	bend = lerpf(bend, 0.55, resting)
	var sweep := sin(time * 1.3) * 0.12 * feeding
	# A lookout swings its head through a wide, slow scan.
	var look := (sin(time * 0.37) * 0.08 + sin(time * 0.91) * 0.04) * (1.0 - walk) * (1.0 - feeding) * (1.0 + 3.0 * watching)
	var sway := sin(phase) * 0.025 * walk
	for index in neck.size():
		var joint := neck[index]
		var pitch := bend / NECK_SEGMENTS + (drop if index == 0 else 0.0)
		# The head leads into a turn.
		var yaw := sweep + look + sway + turn * 0.05
		joint.rotation = Vector3(pitch, yaw, 0.0)
	var chew := maxf(0.0, sin(time * 9.0)) * feeding
	# Feeding, the flat muzzle faces the ground.
	head.rotation = Vector3(lerpf(-0.1, 0.3, feeding) - 0.15 * alert + 0.3 * watching, 0.0, 0.0)
	jaw.rotation.x = 0.28 * chew + 0.05 * (1.0 - feeding)


# Like a slug's, each tentacle moves on its own: the stalk swings slowly
# forward and back and out and in, and stretches and shortens a little as if
# probing, while staying nearly straight with a slight droop at the tip.
# Feeding tips them further toward the ground; fleeing pulls them in.
func _pose_tentacles() -> void:
	for root in tentacles:
		var side: float = root.get_meta("side")
		var pair: int = root.get_meta("pair")
		var shape: Array = TENTACLES[pair]
		var rhythm := float(pair) * 2.1 + side * 1.3
		var swing := sin(time * 0.47 + rhythm) * 0.16 + sin(time * 1.13 + rhythm * 2.3) * 0.05
		var spread := sin(time * 0.31 + rhythm * 1.7) * 0.06
		var reach := 0.9 + 0.1 * sin(time * 0.23 + rhythm * 0.9)
		# Euler order is Y, X, Z: splay about Z tips the stalk outward, then
		# lean about X tips it forward.
		root.rotation = Vector3(float(shape[6]) + swing + 0.2 * feeding - 0.3 * alert, 0.0, -side * (float(shape[5]) + spread) * (1.0 - 0.5 * alert))
		root.scale = Vector3(1.0, reach, 1.0) * lerpf(1.0, 0.25, alert)
		var joint: Node3D = root.get_child(0)
		var index := 0
		while joint != null:
			var wave := sin(time * (0.8 + 0.2 * pair) + rhythm - index * 0.7)
			joint.rotation = Vector3((0.04 * wave + 0.03 * index) * (1.0 - alert), 0.0, -side * 0.03 * wave)
			index += 1
			joint = joint.get_child(1) if joint.get_child_count() > 1 else null


# The tail droops a little and a slow wave runs back along it; it lags behind
# turns and lifts clear of the ground in flight.
func _pose_tail() -> void:
	for index in tail.size():
		var joint := tail[index]
		var reach := float(index) / (tail.size() - 1)
		var droop := lerpf(0.07, -0.03, alert) + 0.04 * sin(time * 1.1 + index * 0.4) * (1.0 - walk)
		var wave := sin(phase - index * 0.7) * 0.07 * walk * (0.4 + reach) + sin(time * 0.8 - index * 0.5) * 0.03 * (1.0 - walk)
		joint.rotation = Vector3(-droop, wave - turn * 0.035, 0.0)


func _pose_legs(stride: float) -> void:
	var body_transform := body.transform
	for index in legs.size():
		var leg := legs[index]
		var side: float = leg.get_meta("side")
		var hind: bool = leg.get_meta("hind")
		var cycle := fposmod(phase / TAU + float(leg.get_meta("offset")), 1.0)
		var swing: float
		var raised := 0.0
		if cycle < DUTY:
			swing = stride * (1.0 - 2.0 * cycle / DUTY)
		else:
			var through := (cycle - DUTY) / (1.0 - DUTY)
			swing = -stride + 2.0 * stride * smoothstep(0.0, 1.0, through)
			raised = sin(PI * through) * STEP_HEIGHT
		swing *= walk
		raised *= walk
		var base: Vector3 = HIND_HIP if hind else FORE_HIP
		var hip := body_transform * Vector3(side * base.x, base.y, base.z)
		var foot := Vector3(side * FOOT_SPREAD, raised, base.z + swing)
		# Hind knees bend forward and fore elbows back, more while the foot
		# swings through.
		var bend := (0.035 + raised * 0.9 + 0.2 * resting) * (1.0 if hind else -1.0)
		var knee := (hip + foot) * 0.5 + Vector3(side * 0.01, 0.0, bend)
		_point_limb(leg.get_child(0), hip, knee)
		_point_limb(leg.get_child(1), knee, foot)
		feet[index].position = foot + Vector3(0.0, 0.025, 0.02)


# A chain of short soft segments running up (+Y) from the head; the long
# upper pair ends in an eye.
func _tentacle(side: float, pair: int) -> Node3D:
	var shape: Array = TENTACLES[pair]
	var root := Node3D.new()
	root.name = "Tentacle%s%d" % ["Left" if side > 0.0 else "Right", pair]
	root.position = Vector3(side * float(shape[2]), shape[3], shape[4])
	root.set_meta("side", side)
	root.set_meta("pair", pair)
	head.add_child(root)
	var segment_length: float = float(shape[0]) / TENTACLE_JOINTS
	var parent: Node3D = root
	for index in TENTACLE_JOINTS:
		var joint := Node3D.new()
		joint.position = Vector3(0.0, 0.0 if index == 0 else segment_length, 0.0)
		parent.add_child(joint)
		var piece := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		var taper := 1.0 - 0.3 * float(index) / TENTACLE_JOINTS
		mesh.bottom_radius = float(shape[1]) * taper
		mesh.top_radius = float(shape[1]) * (taper - 0.3 / TENTACLE_JOINTS)
		mesh.height = segment_length * 1.1
		mesh.radial_segments = 8
		mesh.rings = 1
		piece.mesh = mesh
		piece.position.y = segment_length * 0.5
		piece.material_override = skin
		joint.add_child(piece)
		parent = joint
	if pair == 0:
		_sphere(parent, 0.032, Vector3.ONE, Vector3(0.0, segment_length + 0.016, 0.0), eye)
	else:
		_sphere(parent, float(shape[1]) * 1.2, Vector3.ONE, Vector3(0.0, segment_length, 0.0), skin)
	return root


func _tooth_row(parent: Node3D, centre: Vector3, direction: float) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.011, 0.022, 0.01)
	for index in 19:
		var across := (float(index) / 18.0 - 0.5) * 0.27
		var piece := MeshInstance3D.new()
		piece.mesh = box
		piece.position = centre + Vector3(across, direction * 0.007, -absf(across) * 0.12)
		piece.material_override = tooth
		parent.add_child(piece)


func _limb(radius: float) -> Node3D:
	var joint := Node3D.new()
	var limb := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = 1.0
	capsule.radial_segments = 10
	capsule.rings = 3
	limb.mesh = capsule
	limb.rotation.x = PI * 0.5
	limb.position.z = -0.5
	limb.material_override = skin
	joint.add_child(limb)
	return joint


func _point_limb(joint: Node3D, from: Vector3, to: Vector3) -> void:
	var span := to - from
	var direction := span.normalized()
	joint.transform = Transform3D(Basis.looking_at(direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.FORWARD) * Basis.from_scale(Vector3(1.0, 1.0, span.length())), from)


func _cone(parent: Node3D, radius: float, height: float, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 1
	piece.mesh = mesh
	piece.material_override = material
	parent.add_child(piece)
	return piece


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
