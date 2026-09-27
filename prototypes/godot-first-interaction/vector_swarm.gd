extends Node3D

# THROWAWAY PROTOTYPE.
# The Flying Reproductive Vector drawn as a swarm of small glowing dots. Each
# dot flocks with its neighbours (keeps apart, matches their heading, drifts
# toward them) and is drawn to the swarm's centre, which main.gd moves along
# the simulated animal's path. The swarm streams after the centre when it
# travels and settles low and tight over flowers while feeding. Presentation
# only: one simulated animal, many dots.

const COUNT := 44
const DOT_RADIUS := 0.045
const NEIGHBOUR_RADIUS := 0.6
const SEPARATION_RADIUS := 0.16
const FLYING_SPREAD := 0.55
const FEEDING_SPREAD := 0.28
const FLYING_SPEED := Vector2(0.5, 2.4)
const FEEDING_SPEED := Vector2(0.25, 1.2)

var positions := PackedVector3Array()
var velocities := PackedVector3Array()
var phases := PackedFloat32Array()
var time := 0.0
var placed := false
var dots: MultiMeshInstance3D
var material: StandardMaterial3D
var rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "VectorSwarm"
	rng.seed = 7331
	var sphere := SphereMesh.new()
	sphere.radius = DOT_RADIUS
	sphere.height = DOT_RADIUS * 2.0
	sphere.radial_segments = 6
	sphere.rings = 3
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	sphere.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = sphere
	multimesh.instance_count = COUNT
	dots = MultiMeshInstance3D.new()
	dots.multimesh = multimesh
	# Dots live in world space so the swarm trails behind a moving centre.
	dots.top_level = true
	dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dots)
	positions.resize(COUNT)
	velocities.resize(COUNT)
	phases.resize(COUNT)
	for i in range(COUNT):
		phases[i] = rng.randf() * TAU
	set_color(Color("e9d36a"))


# Tints the swarm, e.g. pink while it carries canopy pollen. Each dot keeps a
# slightly different brightness so the swarm shimmers.
func set_color(color: Color) -> void:
	for i in range(COUNT):
		var shade := 0.75 + 0.5 * fposmod(phases[i] * 0.37, 1.0)
		dots.multimesh.set_instance_color(i, Color(color.r * shade, color.g * shade, color.b * shade))


func animate(delta: float, centre: Vector3, feeding: bool) -> void:
	if delta <= 0.0:
		return
	if not placed or positions[0].distance_to(centre) > 6.0:
		_emerge(centre)
	time += delta
	var spread := FEEDING_SPREAD if feeding else FLYING_SPREAD
	var speed_range := FEEDING_SPEED if feeding else FLYING_SPEED
	# Feeding dots hang lower, just above the blossoms.
	var home := centre + (Vector3(0.0, -0.18, 0.0) if feeding else Vector3.ZERO)
	var next_velocities := velocities.duplicate()
	for i in range(COUNT):
		var here := positions[i]
		var separation := Vector3.ZERO
		var heading := Vector3.ZERO
		var gathering := Vector3.ZERO
		var neighbours := 0
		for j in range(COUNT):
			if i == j:
				continue
			var offset := here - positions[j]
			var distance := offset.length()
			if distance < NEIGHBOUR_RADIUS:
				heading += velocities[j]
				gathering += positions[j]
				neighbours += 1
				if distance < SEPARATION_RADIUS and distance > 0.0001:
					separation += offset / (distance * distance)
		var steer := separation * 0.05
		if neighbours > 0:
			steer += (heading / neighbours - velocities[i]) * 0.9
			steer += (gathering / neighbours - here) * 1.1
		# Drawn to the centre, gently inside the swarm and strongly beyond it.
		var to_home := home - here
		var reach := to_home.length()
		steer += to_home * (1.4 if reach < spread else 1.4 + 6.0 * (reach - spread))
		# Each dot wanders on its own slow rhythm so the swarm never settles.
		var phase := phases[i]
		steer += Vector3(sin(time * 2.3 + phase), 0.6 * sin(time * 3.1 + phase * 1.7), cos(time * 1.9 + phase * 0.8)) * 1.6
		var velocity := velocities[i] + steer * delta
		var speed := velocity.length()
		if speed > speed_range.y:
			velocity = velocity / speed * speed_range.y
		elif speed < speed_range.x and speed > 0.0001:
			velocity = velocity / speed * speed_range.x
		next_velocities[i] = velocity
	velocities = next_velocities
	for i in range(COUNT):
		positions[i] += velocities[i] * delta
		# Never sink far below the centre, which itself stays above the ground.
		positions[i].y = maxf(positions[i].y, centre.y - 0.4)
		dots.multimesh.set_instance_transform(i, Transform3D(Basis(), positions[i]))


# The swarm rises out of the soil: every dot starts close to the ground below
# the centre and climbs out with a little outward scatter.
func _emerge(centre: Vector3) -> void:
	placed = true
	for i in range(COUNT):
		var angle := rng.randf() * TAU
		var radius := rng.randf() * 0.2
		positions[i] = centre + Vector3(cos(angle) * radius, -0.35 + rng.randf() * 0.1, sin(angle) * radius)
		velocities[i] = Vector3(cos(angle) * 0.4, 0.9 + rng.randf() * 0.5, sin(angle) * 0.4)
		dots.multimesh.set_instance_transform(i, Transform3D(Basis(), positions[i]))
