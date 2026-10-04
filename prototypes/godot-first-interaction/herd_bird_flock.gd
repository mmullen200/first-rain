extends Node3D

# THROWAWAY PROTOTYPE.
# A small flock of herd birds (#52), after oxpeckers and cattle egrets: white
# birds with grey wings and bright orange bills that ride on the grazers' backs and
# hop about their feet picking insects from the dung. Every few seconds a bird
# flits to another grazer or down to the ground. When the flock raises the
# alarm every bird bursts up off the herd, calling, and circles high and fast
# over it until the danger has passed, then drops back onto the backs.
# Presentation only: the simulation says which herd the flock is with and
# when it is alarmed; main.gd hands in the grazer bodies to land on.

const BACK_HEIGHT := 0.66
const FLIGHT_SECONDS := 0.7
const ALARM_HEIGHT := 3.2
const ALARM_RADIUS := 2.4
# Larger than an oxpecker, so a bird reads from the game camera.
const BIRD_SCALE := 2.2

var birds: Array[Dictionary] = []
var time := 0.0
var _rng := RandomNumberGenerator.new()


func _init(count := 5, flock_seed := 1) -> void:
	name = "HerdBirdFlock"
	top_level = true
	_rng.seed = flock_seed
	# White like a cattle egret, so the flock stands out against the herd and
	# the ground; grey wings, orange bill, yellow eye-ring.
	var feathers := _material(Color("f2eee4"), 0.8)
	var chest := _material(Color("fffaf0"), 0.8)
	var wing_feathers := _material(Color("9a9890"), 0.8)
	var bill := _material(Color("f0632a"), 0.5, Color("6e2008"))
	var ring := _material(Color("f4d14a"), 0.5, Color("5a4a08"))
	for index in count:
		var bird := Node3D.new()
		bird.name = "Bird%d" % index
		bird.scale = Vector3.ONE * BIRD_SCALE
		add_child(bird)
		var body := _sphere(bird, 0.06, Vector3(0.9, 0.85, 1.5), Vector3(0.0, 0.05, 0.0), feathers)
		_sphere(body, 0.05, Vector3(0.8, 0.7, 1.1), Vector3(0.0, -0.015, 0.012), chest)
		var head := _sphere(bird, 0.04, Vector3.ONE, Vector3(0.0, 0.1, 0.075), feathers)
		for side in [-1.0, 1.0]:
			_sphere(head, 0.012, Vector3.ONE, Vector3(side * 0.03, 0.01, 0.015), ring)
		var beak := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.016
		cone.height = 0.06
		beak.mesh = cone
		beak.material_override = bill
		beak.rotation.x = PI * 0.5
		beak.position = Vector3(0.0, -0.005, 0.055)
		head.add_child(beak)
		var tail := _sphere(bird, 0.04, Vector3(0.7, 0.2, 1.4), Vector3(0.0, 0.06, -0.1), feathers)
		tail.rotation.x = -0.3
		var wings: Array[Node3D] = []
		for side in [-1.0, 1.0]:
			var hinge := Node3D.new()
			hinge.position = Vector3(side * 0.045, 0.08, 0.0)
			bird.add_child(hinge)
			var wing := _sphere(hinge, 0.06, Vector3(1.6, 0.12, 0.9), Vector3(side * 0.08, 0.0, -0.01), wing_feathers)
			wing.name = "Wing"
			wings.append(hinge)
		birds.append({
			"node": bird,
			"wings": wings,
			"head": head,
			"host": index,
			"perch": "back",
			"spot": Vector2(_rng.randf_range(-0.25, 0.25), _rng.randf_range(-0.2, 0.25)),
			"from": Vector3.ZERO,
			"flight": 0.0,
			"next_move": _rng.randf_range(2.0, 6.0),
			"angle": TAU * float(index) / float(count),
			"placed": false,
			"airborne": 0.0
		})


# `hosts` are the grazer bodies of the herd the flock is with. `alarmed` is
# true while the simulation's alarm lasts; the flock circles over `centre`.
func update(delta: float, hosts: Array[Node3D], alarmed: bool, centre: Vector3) -> void:
	if delta <= 0.0 or hosts.is_empty():
		return
	time += delta
	for bird in birds:
		var node: Node3D = bird["node"]
		var target: Vector3
		var facing := node.rotation.y
		var flying := false
		if alarmed:
			var angle := float(bird["angle"]) + time * 1.6
			target = centre + Vector3(cos(angle) * ALARM_RADIUS, ALARM_HEIGHT + 0.4 * sin(time * 2.0 + float(bird["angle"])), sin(angle) * ALARM_RADIUS)
			facing = atan2(-sin(angle), cos(angle))
			flying = true
			bird["perch"] = "air"
		else:
			bird["next_move"] = float(bird["next_move"]) - delta
			if bird["perch"] == "air" or float(bird["next_move"]) <= 0.0 or int(bird["host"]) >= hosts.size():
				_choose_new_spot(bird, hosts.size())
			var host: Node3D = hosts[int(bird["host"]) % hosts.size()]
			var spot: Vector2 = bird["spot"]
			if bird["perch"] == "back":
				# Riding along the grazer's back, facing its way.
				var along := host.global_transform.basis.z * spot.y + host.global_transform.basis.x * spot.x * 0.4
				target = host.global_position + along + Vector3(0.0, BACK_HEIGHT * host.scale.y, 0.0)
				facing = host.global_rotation.y
			else:
				# Hopping on the ground beside the grazer's feet.
				var beside := Vector3(spot.x * 2.4, 0.0, spot.y * 2.4)
				target = host.global_position + beside
				target.y = host.global_position.y - 0.25
				target.y += absf(sin(time * 6.0 + float(bird["angle"]))) * 0.03
			if float(bird["flight"]) < 1.0:
				flying = true
		if not bool(bird["placed"]):
			node.global_position = target
			bird["placed"] = true
			bird["flight"] = 1.0
		var progress := float(bird["flight"])
		if progress < 1.0:
			# A short hop-flight: an arc from where it was to the new spot.
			progress = minf(1.0, progress + delta / FLIGHT_SECONDS)
			bird["flight"] = progress
			var from: Vector3 = bird["from"]
			var position := from.lerp(target, progress)
			position.y += sin(progress * PI) * 0.6
			var travel := target - from
			if Vector2(travel.x, travel.z).length() > 0.01:
				facing = atan2(travel.x, travel.z)
			node.global_position = position
		elif alarmed:
			node.global_position = node.global_position.lerp(target, clampf(delta * 3.0, 0.0, 1.0))
		else:
			node.global_position = node.global_position.lerp(target, clampf(delta * 12.0, 0.0, 1.0))
		node.rotation.y = lerp_angle(node.rotation.y, facing, clampf(delta * 8.0, 0.0, 1.0))
		bird["airborne"] = lerpf(float(bird["airborne"]), 1.0 if flying else 0.0, clampf(delta * 10.0, 0.0, 1.0))
		_pose(bird)


func alarmed_birds_above(height: float) -> int:
	var count := 0
	for bird in birds:
		if bird["perch"] == "air" and (bird["node"] as Node3D).global_position.y > height:
			count += 1
	return count


func _choose_new_spot(bird: Dictionary, host_count: int) -> void:
	bird["from"] = (bird["node"] as Node3D).global_position
	bird["flight"] = 0.0 if bool(bird["placed"]) else 1.0
	bird["host"] = _rng.randi_range(0, maxi(0, host_count - 1))
	bird["perch"] = "back" if _rng.randf() < 0.65 else "ground"
	bird["spot"] = Vector2(_rng.randf_range(-0.25, 0.25), _rng.randf_range(-0.2, 0.25))
	bird["next_move"] = _rng.randf_range(3.0, 9.0)


# Wings beat while flying and fold along the body at rest; at rest the head
# pecks now and then.
func _pose(bird: Dictionary) -> void:
	var airborne := float(bird["airborne"])
	var beat := sin(time * 26.0 + float(bird["angle"]) * 3.0) * 0.9 * airborne
	var wings: Array[Node3D] = bird["wings"]
	for index in wings.size():
		var side := -1.0 if index == 0 else 1.0
		wings[index].rotation = Vector3(0.0, side * 0.5 * (1.0 - airborne), side * (beat + 0.15 * (1.0 - airborne)))
	var head: Node3D = bird["head"]
	var peck := maxf(0.0, sin(time * 3.1 + float(bird["angle"]) * 5.0)) * (1.0 - airborne)
	head.rotation.x = 0.6 * peck * peck


func _sphere(parent: Node3D, radius: float, scale_value: Vector3, offset: Vector3, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	piece.mesh = mesh
	piece.scale = scale_value
	piece.position = offset
	piece.material_override = material
	parent.add_child(piece)
	return piece


func _material(color: Color, roughness: float, emission := Color(0.0, 0.0, 0.0, 1.0)) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	if emission != Color(0.0, 0.0, 0.0, 1.0):
		result.emission_enabled = true
		result.emission = emission
	return result
