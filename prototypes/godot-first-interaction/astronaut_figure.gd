extends Node3D

# THROWAWAY PROTOTYPE.
# Stylized toy-like astronaut built from primitive meshes, with a procedural
# walk cycle. Presentation only: the CharacterBody3D parent owns position,
# collision and facing. The figure faces local +Z, matching the parent's
# movement heading, and stands about 1.65 m tall with its feet at y = 0.

const HIP_HEIGHT := 0.5
const LEG_LENGTH := 0.5
const STRIDE_RADIANS_PER_METRE := 4.4
const HIP_SWING := 0.55
const KNEE_BEND := 0.85
const ARM_SWING := 0.5
const REFERENCE_SPEED := 1.9

var body_root: Node3D
var torso_group: Node3D
var left_hip: Node3D
var right_hip: Node3D
var left_knee: Node3D
var right_knee: Node3D
var left_shoulder: Node3D
var right_shoulder: Node3D
var left_elbow: Node3D
var right_elbow: Node3D

var stride_phase := 0.0
var walk_amount := 0.0
var idle_time := 0.0

var suit_material: StandardMaterial3D
var joint_material: StandardMaterial3D
var trim_material: StandardMaterial3D
var visor_material: StandardMaterial3D
var detail_material: StandardMaterial3D


func _init() -> void:
	name = "AstronautFigure"
	suit_material = _material(Color("f1f1ee"), 0.34)
	joint_material = _material(Color("d3d6d8"), 0.42)
	trim_material = _material(Color("ea7d25"), 0.45)
	detail_material = _material(Color("4a4f55"), 0.5)
	visor_material = _material(Color("0d0f12"), 0.06)
	visor_material.metallic = 0.55
	visor_material.metallic_specular = 0.9
	_build()


func animate(delta: float, horizontal_speed: float) -> void:
	if delta <= 0.0:
		return
	var target := clampf(horizontal_speed / REFERENCE_SPEED, 0.0, 1.0)
	walk_amount = lerpf(walk_amount, target, clampf(delta * 9.0, 0.0, 1.0))
	# Advance the stride by distance travelled so feet do not skate.
	stride_phase = fmod(stride_phase + horizontal_speed * delta * STRIDE_RADIANS_PER_METRE, TAU)
	idle_time += delta

	var swing := sin(stride_phase)
	var hip_angle := HIP_SWING * walk_amount * swing
	left_hip.rotation.x = -hip_angle
	right_hip.rotation.x = hip_angle
	# A leg bends its knee while swinging forward and straightens to plant.
	left_knee.rotation.x = KNEE_BEND * walk_amount * maxf(0.0, -cos(stride_phase))
	right_knee.rotation.x = KNEE_BEND * walk_amount * maxf(0.0, cos(stride_phase))

	left_shoulder.rotation.x = ARM_SWING * walk_amount * swing
	right_shoulder.rotation.x = -ARM_SWING * walk_amount * swing
	left_elbow.rotation.x = -0.2 - 0.35 * walk_amount * maxf(0.0, -swing)
	right_elbow.rotation.x = -0.2 - 0.35 * walk_amount * maxf(0.0, swing)

	# Drop the hips by exactly what the planted leg's angle shortens it, so the
	# standing foot stays on the ground; add a slow breath when standing still.
	var leg_drop := LEG_LENGTH * (1.0 - cos(hip_angle))
	var breath := sin(idle_time * 1.7) * 0.007 * (1.0 - walk_amount)
	body_root.position.y = -leg_drop + breath
	body_root.rotation.x = 0.07 * walk_amount
	torso_group.rotation.y = 0.09 * walk_amount * swing
	torso_group.rotation.z = 0.03 * walk_amount * swing


func _build() -> void:
	body_root = _pivot(self, "Body", Vector3.ZERO)

	left_hip = _pivot(body_root, "LeftHip", Vector3(0.12, HIP_HEIGHT, 0.0))
	right_hip = _pivot(body_root, "RightHip", Vector3(-0.12, HIP_HEIGHT, 0.0))
	left_knee = _build_leg(left_hip)
	right_knee = _build_leg(right_hip)

	torso_group = _pivot(body_root, "Torso", Vector3.ZERO)
	_build_torso()

	left_shoulder = _pivot(torso_group, "LeftShoulder", Vector3(0.29, 0.99, 0.0))
	right_shoulder = _pivot(torso_group, "RightShoulder", Vector3(-0.29, 0.99, 0.0))
	left_shoulder.rotation.z = 0.14
	right_shoulder.rotation.z = -0.14
	left_elbow = _build_arm(left_shoulder)
	right_elbow = _build_arm(right_shoulder)

	_build_helmet()


func _build_leg(hip: Node3D) -> Node3D:
	_part(hip, _capsule(0.105, 0.28), suit_material, Vector3(0.0, -0.12, 0.0))
	_part(hip, _box(Vector3(0.1, 0.026, 0.02)), trim_material, Vector3(0.0, -0.1, 0.1))
	var knee := _pivot(hip, "Knee", Vector3(0.0, -0.24, 0.0))
	_part(knee, _sphere(0.1), joint_material, Vector3.ZERO)
	_part(knee, _capsule(0.1, 0.22), suit_material, Vector3(0.0, -0.09, 0.0))
	var boot := _part(knee, _capsule(0.1, 0.32), joint_material, Vector3(0.0, -0.19, 0.04))
	boot.rotation.x = PI * 0.5
	boot.scale = Vector3(1.05, 1.0, 0.72)
	return knee


func _build_arm(shoulder: Node3D) -> Node3D:
	_part(shoulder, _sphere(0.1), suit_material, Vector3.ZERO)
	_part(shoulder, _capsule(0.085, 0.26), suit_material, Vector3(0.0, -0.1, 0.0))
	_part(shoulder, _cylinder(0.09, 0.026), trim_material, Vector3(0.0, -0.06, 0.0))
	var elbow := _pivot(shoulder, "Elbow", Vector3(0.0, -0.2, 0.0))
	_part(elbow, _capsule(0.08, 0.2), suit_material, Vector3(0.0, -0.07, 0.0))
	_part(elbow, _cylinder(0.086, 0.04), joint_material, Vector3(0.0, -0.15, 0.0))
	_part(elbow, _sphere(0.085), joint_material, Vector3(0.0, -0.21, 0.01))
	return elbow


func _build_torso() -> void:
	var trunk := _part(torso_group, _capsule(0.235, 0.62), suit_material, Vector3(0.0, 0.8, 0.0))
	trunk.scale = Vector3(1.0, 1.0, 0.8)
	var belt := _part(torso_group, _cylinder(0.24, 0.055), joint_material, Vector3(0.0, 0.6, 0.0))
	belt.scale = Vector3(1.0, 1.0, 0.82)
	_part(torso_group, _box(Vector3(0.1, 0.03, 0.02)), detail_material, Vector3(0.0, 0.6, 0.2))

	# Chest control unit with two dials, like the reference toy.
	_part(torso_group, _box(Vector3(0.2, 0.2, 0.06)), joint_material, Vector3(0.0, 0.83, 0.18))
	_part(torso_group, _box(Vector3(0.1, 0.05, 0.02)), suit_material, Vector3(0.0, 0.88, 0.215))
	for side in [-1.0, 1.0]:
		_part(torso_group, _sphere(0.032), detail_material, Vector3(0.14 * side, 0.9, 0.17))
		# Orange trim running down each side of the chest.
		var strap := _part(torso_group, _box(Vector3(0.03, 0.34, 0.02)), trim_material, Vector3(0.2 * side, 0.83, 0.13))
		strap.rotation.y = -0.5 * side
		var hip_trim := _part(torso_group, _box(Vector3(0.13, 0.026, 0.02)), trim_material, Vector3(0.1 * side, 0.52, 0.17))
		hip_trim.rotation.z = -0.3 * side

	_part(torso_group, _box(Vector3(0.32, 0.36, 0.15)), joint_material, Vector3(0.0, 0.84, -0.2))
	_part(torso_group, _cylinder(0.17, 0.07), joint_material, Vector3(0.0, 1.07, 0.0))


func _build_helmet() -> void:
	var helmet := _pivot(torso_group, "Helmet", Vector3(0.0, 1.35, 0.0))
	var shell := _part(helmet, _sphere(0.33), suit_material, Vector3.ZERO)
	shell.scale = Vector3(1.05, 0.98, 1.0)
	var visor := _part(helmet, _sphere(0.22), visor_material, Vector3(0.0, -0.01, 0.23))
	visor.scale = Vector3(1.3, 0.84, 0.55)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.27
	torus.outer_radius = 0.315
	rim.mesh = torus
	rim.material_override = suit_material
	rim.position = Vector3(0.0, -0.01, 0.2)
	rim.rotation.x = PI * 0.5
	rim.scale = Vector3(1.1, 0.6, 0.72)
	helmet.add_child(rim)
	for side in [-1.0, 1.0]:
		var pod := _part(helmet, _cylinder(0.1, 0.09), joint_material, Vector3(0.32 * side, 0.0, -0.02))
		pod.rotation.z = PI * 0.5


func _pivot(parent: Node3D, pivot_name: String, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = pivot_name
	pivot.position = at
	parent.add_child(pivot)
	return pivot


func _part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return mesh


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return mesh


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
