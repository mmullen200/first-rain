extends Node3D

# THROWAWAY PROTOTYPE.
# This scene tests whether a first Field Experiment teaches itself through
# movement, local comparison, scarce intervention, and ecological feedback.

const WALK_SPEED := 4.3
const WORLD_X := 8.8
const WORLD_Z := 6.2
const ECOLOGY_STEP_SECONDS := 0.34
const EcologyGridModel = preload("res://ecology_grid.gd")

var astronaut: CharacterBody3D
var camera: Camera3D
var ecology
var ecology_cells: Array[MeshInstance3D] = []
var ecology_step_accumulator := 0.0
var ecology_started := false
var moss_spread_announced := false
var fungus_announced := false
var fruiting_announced := false
var water_doses := 0
var ration_packs := 0
var fresh_food := 0
var hunger := 34.0
var exposure := 0.0
var field_time := 0.0
var scanner_recovered := false
var cache_opened := false
var discoveries: Array[String] = []
var patches: Dictionary = {}
var nearest_patch := ""
var near_cache := false
var nearest_harvest_cell := Vector2i(-1, -1)
var near_refuge := false
var refuge_position := Vector3(0.35, 0.03, 3.25)
var refuge_marker: Node3D
var refuge_revealed := false
var emergency_cache: MeshInstance3D
var shade_panel: MeshInstance3D
var shade_panel_home := Vector3(-5.4, 0.32, 2.7)
var carrying_shade := false
var shade_placed := false
var presence_root: Node3D
var presence_target := Vector3(0.8, 1.3, -5.45)

var grazer_root: Node3D
var grazer_body: MeshInstance3D
var grazer_head: MeshInstance3D
var grazer_label: Label3D
var grazer_glow: OmniLight3D
var grazer_awake := false
var grazer_cell := Vector2i.ZERO
var grazer_target_position := Vector3.ZERO
var grazer_step_timer := 0.0
var grazer_failed_to_feed := 0

var disturbance_state := "quiet"
var disturbance_timer := 0.0
var disturbance_column := -1
var dust_front: MeshInstance3D

var water_label: Label
var exposure_label: Label
var hunger_label: Label
var weather_label: Label
var prompt_label: Label
var status_label: Label
var scanner_card: PanelContainer
var scanner_title: Label
var scanner_readout: Label
var discovery_readout: Label
var time_label: Label
var ecosystem_label: Label


func _ready() -> void:
	_build_world()
	_build_ecology_grid()
	_build_astronaut()
	_build_patches()
	_build_presence()
	_build_refuge()
	_build_grazer()
	_build_disturbance()
	_build_interface()
	_set_status("The crash has stopped. The ship is dead, but an emergency cache still blinks beneath the broken wing.")


func _physics_process(delta: float) -> void:
	field_time += delta
	_move_astronaut(delta)
	_update_camera()
	_update_nearby_interactions()
	_update_exposure(delta)
	_update_hunger(delta)
	_update_ecology(delta)
	_update_ecology_grid(delta)
	_update_grazer(delta)
	_update_disturbance(delta)
	_update_presence()
	_update_interface()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_F:
			_scan_nearby_patch()
		KEY_SPACE:
			_water_nearby_patch()
		KEY_E:
			_interact()
		KEY_Q:
			_use_water_for_survival()
		KEY_Z:
			_eat_food()
		KEY_R:
			get_tree().reload_current_scene()


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("111820")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("91a0a8")
	env.ambient_light_energy = 0.45
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -32.0, 0.0)
	sun.light_color = Color("efd6ad")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	var ground_body := StaticBody3D.new()
	ground_body.name = "BasinGround"
	add_child(ground_body)

	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 14.5)
	ground_mesh.mesh = plane
	ground_mesh.material_override = _material(Color("3e4241"), 0.92)
	ground_body.add_child(ground_mesh)

	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(20.0, 0.2, 14.5)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.12
	ground_body.add_child(ground_collision)

	# Wreckage creates a readable origin and a grace-period shelter.
	_create_box(Vector3(-5.8, 0.55, -3.7), Vector3(3.6, 1.05, 1.65), Color("697276"), Vector3(0.0, 0.28, 0.0))
	_create_box(Vector3(-4.3, 0.28, -2.6), Vector3(4.7, 0.13, 1.2), Color("879095"), Vector3(0.0, -0.24, 0.05))
	_create_box(Vector3(-6.1, 1.15, -3.55), Vector3(1.25, 0.52, 1.1), Color("29343b"), Vector3(0.0, 0.28, 0.0))
	emergency_cache = _create_box(Vector3(-5.15, 0.24, -1.72), Vector3(0.9, 0.45, 0.62), Color("8e7048"), Vector3(0.0, 0.16, 0.0))
	emergency_cache.name = "EmergencyCache"
	var cache_light := OmniLight3D.new()
	cache_light.name = "CacheBeacon"
	cache_light.position = Vector3(-5.15, 0.62, -1.72)
	cache_light.light_color = Color("e7a34f")
	cache_light.light_energy = 1.5
	cache_light.omni_range = 1.35
	add_child(cache_light)
	_create_world_label("EMERGENCY CACHE", Vector3(-5.15, 0.68, -1.72), Color("ffd18b"), 0.0055)

	# The sheltered hollow reads through shade, darker ground, and surrounding stones.
	var shelter_panel_color := Color("555b59")
	shelter_panel_color.a = 0.5
	var shelter_panel := _create_box(Vector3(-2.8, 1.25, -1.55), Vector3(3.2, 0.16, 1.55), shelter_panel_color, Vector3(0.0, -0.18, -0.08))
	shelter_panel.name = "ShelterPanel"
	for position in [Vector3(-3.7, 0.28, -0.8), Vector3(-1.8, 0.22, -2.35), Vector3(-3.65, 0.2, -2.35)]:
		_create_rock(position, 0.55)

	# The exposed crust reads through pale stones and a hot toxic vent.
	for position in [Vector3(3.4, 0.18, 2.6), Vector3(4.9, 0.24, 1.0), Vector3(5.2, 0.18, 2.5)]:
		_create_rock(position, 0.42, Color("8d8068"))
	var vent := _create_cylinder(Vector3(5.0, 0.34, 1.65), 0.24, 0.66, Color("765b45"))
	vent.name = "ToxicVent"
	var vent_light := OmniLight3D.new()
	vent_light.position = Vector3(5.0, 0.7, 1.65)
	vent_light.light_color = Color("e5a557")
	vent_light.light_energy = 0.9
	vent_light.omni_range = 2.4
	add_child(vent_light)

	shade_panel = _create_box(shade_panel_home, Vector3(1.45, 0.09, 0.85), Color("839199"), Vector3(0.0, 0.22, -0.08))
	shade_panel.name = "LooseShadePanel"
	_create_world_label("LOOSE WRECK PANEL", shade_panel_home + Vector3(0.0, 0.45, 0.0), Color("e4e8e4"), 0.0055)


func _build_ecology_grid() -> void:
	ecology = EcologyGridModel.new()
	var root := Node3D.new()
	root.name = "ProvisionalEcologicalCells"
	add_child(root)
	for y in range(EcologyGridModel.HEIGHT):
		for x in range(EcologyGridModel.WIDTH):
			var cell := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(EcologyGridModel.CELL_SIZE - 0.08, 0.024, EcologyGridModel.CELL_SIZE - 0.08)
			cell.mesh = mesh
			var world: Vector2 = ecology.world_position(x, y)
			cell.position = Vector3(world.x, 0.012, world.y)
			cell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(cell)
			ecology_cells.append(cell)
	_refresh_ecology_visuals()


func _build_astronaut() -> void:
	astronaut = CharacterBody3D.new()
	astronaut.name = "Astronaut"
	astronaut.position = Vector3(-5.25, 0.0, -1.65)
	add_child(astronaut)

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.35
	collision.shape = shape
	collision.position.y = 0.68
	astronaut.add_child(collision)

	var suit := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.34
	capsule.height = 1.35
	suit.mesh = capsule
	suit.material_override = _material(Color("d9d1bd"), 0.58)
	suit.position.y = 0.68
	astronaut.add_child(suit)

	var visor := MeshInstance3D.new()
	var visor_mesh := SphereMesh.new()
	visor_mesh.radius = 0.29
	visor_mesh.height = 0.48
	visor.mesh = visor_mesh
	visor.material_override = _material(Color("334653"), 0.25, Color("7699ad"))
	visor.position = Vector3(0.0, 1.32, -0.12)
	visor.scale = Vector3(1.0, 0.85, 0.75)
	astronaut.add_child(visor)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.8
	camera.position = astronaut.position + Vector3(8.8, 10.8, 10.5)
	add_child(camera)
	_update_camera()


func _build_patches() -> void:
	patches["hollow"] = _create_patch(
		"hollow",
		"SHELTERED FILM",
		Vector3(-2.7, 0.04, -1.55),
		Color("5c6250"),
		true
	)
	patches["crust"] = _create_patch(
		"crust",
		"SUN-STRUCK FILM",
		Vector3(4.15, 0.04, 1.75),
		Color("8c826c"),
		false
	)


func _build_presence() -> void:
	presence_root = Node3D.new()
	presence_root.name = "DistantPresence"
	presence_root.position = Vector3(0.8, 1.3, -5.45)
	presence_root.visible = false
	add_child(presence_root)

	var outer := MeshInstance3D.new()
	var outer_mesh := SphereMesh.new()
	outer_mesh.radius = 0.28
	outer_mesh.height = 0.72
	outer.mesh = outer_mesh
	outer.scale = Vector3(0.78, 1.35, 0.78)
	outer.material_override = _material(Color("f0a451"), 0.18, Color("ff9a3d"))
	presence_root.add_child(outer)

	var inner := MeshInstance3D.new()
	var inner_mesh := SphereMesh.new()
	inner_mesh.radius = 0.14
	inner_mesh.height = 0.38
	inner.mesh = inner_mesh
	inner.position.y = -0.05
	inner.material_override = _material(Color("ffe0a3"), 0.1, Color("ffdd89"))
	presence_root.add_child(inner)

	var glow := OmniLight3D.new()
	glow.light_color = Color("ffad55")
	glow.light_energy = 2.2
	glow.omni_range = 3.2
	presence_root.add_child(glow)


func _build_refuge() -> void:
	refuge_marker = Node3D.new()
	refuge_marker.name = "PresenceMoistureNudge"
	refuge_marker.position = refuge_position
	refuge_marker.visible = false
	add_child(refuge_marker)

	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.78
	ring_mesh.bottom_radius = 0.88
	ring_mesh.height = 0.035
	ring_mesh.radial_segments = 48
	ring.mesh = ring_mesh
	ring.material_override = _material(Color("3f7180"), 0.45, Color("214957"))
	refuge_marker.add_child(ring)

	var glow := OmniLight3D.new()
	glow.position.y = 0.35
	glow.light_color = Color("68c7d3")
	glow.light_energy = 1.35
	glow.omni_range = 2.2
	refuge_marker.add_child(glow)


func _build_grazer() -> void:
	grazer_cell = ecology.world_to_cell(Vector2(-1.25, 0.15))
	var world: Vector2 = ecology.world_position(grazer_cell.x, grazer_cell.y)
	grazer_root = Node3D.new()
	grazer_root.name = "PrototypeGrazer"
	grazer_root.position = Vector3(world.x, 0.28, world.y)
	grazer_target_position = grazer_root.position
	add_child(grazer_root)

	grazer_body = MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.24
	body_mesh.height = 0.38
	grazer_body.mesh = body_mesh
	grazer_body.scale = Vector3(1.35, 0.62, 0.9)
	grazer_body.material_override = _material(Color("65665f"), 0.94)
	grazer_root.add_child(grazer_body)

	grazer_head = MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.15
	head_mesh.height = 0.25
	grazer_head.mesh = head_mesh
	grazer_head.position = Vector3(0.0, 0.02, -0.3)
	grazer_head.material_override = _material(Color("5b5c56"), 0.9)
	grazer_root.add_child(grazer_head)

	grazer_label = Label3D.new()
	grazer_label.text = "GRAZER"
	grazer_label.position = Vector3(0.0, 0.68, 0.0)
	grazer_label.font_size = 30
	grazer_label.pixel_size = 0.0045
	grazer_label.modulate = Color("9ee8d8")
	grazer_label.outline_size = 8
	grazer_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	grazer_label.visible = false
	grazer_root.add_child(grazer_label)

	grazer_glow = OmniLight3D.new()
	grazer_glow.position.y = 0.35
	grazer_glow.light_color = Color("65d6c0")
	grazer_glow.light_energy = 0.8
	grazer_glow.omni_range = 1.35
	grazer_glow.visible = false
	grazer_root.add_child(grazer_glow)


func _build_disturbance() -> void:
	dust_front = _create_box(Vector3(-6.0, 1.15, 0.0), Vector3(0.34, 2.3, 8.2), Color("b97845"))
	dust_front.name = "HeatDustFront"
	var dust_material := StandardMaterial3D.new()
	dust_material.albedo_color = Color(0.78, 0.39, 0.16, 0.34)
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_front.material_override = dust_material
	dust_front.visible = false


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var title := Label.new()
	title.position = Vector2(24, 18)
	title.text = "FIRST RAIN  /  THROWAWAY OPENING SLICE"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("e9b36e"))
	canvas.add_child(title)

	water_label = Label.new()
	water_label.position = Vector2(24, 47)
	water_label.add_theme_font_size_override("font_size", 22)
	canvas.add_child(water_label)

	exposure_label = Label.new()
	exposure_label.position = Vector2(24, 102)
	exposure_label.add_theme_font_size_override("font_size", 14)
	exposure_label.add_theme_color_override("font_color", Color("b9c1be"))
	canvas.add_child(exposure_label)

	hunger_label = Label.new()
	hunger_label.position = Vector2(24, 78)
	hunger_label.add_theme_font_size_override("font_size", 14)
	hunger_label.add_theme_color_override("font_color", Color("d6b986"))
	canvas.add_child(hunger_label)

	time_label = Label.new()
	time_label.position = Vector2(24, 126)
	time_label.add_theme_font_size_override("font_size", 14)
	time_label.add_theme_color_override("font_color", Color("8f9b98"))
	canvas.add_child(time_label)

	ecosystem_label = Label.new()
	ecosystem_label.position = Vector2(24, 150)
	ecosystem_label.add_theme_font_size_override("font_size", 14)
	ecosystem_label.add_theme_color_override("font_color", Color("8fc99a"))
	canvas.add_child(ecosystem_label)

	weather_label = Label.new()
	weather_label.position = Vector2(24, 174)
	weather_label.add_theme_font_size_override("font_size", 14)
	weather_label.add_theme_color_override("font_color", Color("d89662"))
	canvas.add_child(weather_label)

	var controls := Label.new()
	controls.position = Vector2(24, 606)
	controls.text = "WASD / ARROWS move   E interact/harvest   F scan   SPACE water   Q drink   Z eat   R restart"
	controls.add_theme_font_size_override("font_size", 14)
	controls.add_theme_color_override("font_color", Color("aeb7b4"))
	canvas.add_child(controls)

	prompt_label = Label.new()
	prompt_label.position = Vector2(24, 562)
	prompt_label.size = Vector2(730, 34)
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color("f0bf7c"))
	canvas.add_child(prompt_label)

	status_label = Label.new()
	status_label.position = Vector2(24, 500)
	status_label.size = Vector2(730, 58)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 17)
	canvas.add_child(status_label)

	scanner_card = PanelContainer.new()
	scanner_card.position = Vector2(765, 24)
	scanner_card.size = Vector2(360, 410)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.055, 0.09, 0.095, 0.94)
	card_style.border_color = Color("6f8079")
	card_style.set_border_width_all(1)
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	scanner_card.add_theme_stylebox_override("panel", card_style)
	canvas.add_child(scanner_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 17)
	margin.add_theme_constant_override("margin_right", 17)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	scanner_card.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	margin.add_child(stack)

	scanner_title = Label.new()
	scanner_title.text = "FIELD SCANNER  /  NOT RECOVERED"
	scanner_title.add_theme_font_size_override("font_size", 16)
	scanner_title.add_theme_color_override("font_color", Color("83d1b2"))
	stack.add_child(scanner_title)

	scanner_readout = Label.new()
	scanner_readout.text = "NO DEVICE LINK\n\nThe astronaut's scientific kit was thrown into the emergency cache during impact."
	scanner_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scanner_readout.add_theme_font_size_override("font_size", 14)
	scanner_readout.add_theme_color_override("font_color", Color("c4d4cd"))
	stack.add_child(scanner_readout)

	var separator := HSeparator.new()
	stack.add_child(separator)

	discovery_readout = Label.new()
	discovery_readout.text = "DISCOVERY RECORD\n— unavailable —"
	discovery_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	discovery_readout.add_theme_font_size_override("font_size", 13)
	discovery_readout.add_theme_color_override("font_color", Color("8fa99e"))
	stack.add_child(discovery_readout)

	# A visible crack makes the instrument's damage legible without corrupting readings.
	for crack_data in [[Vector2(1015, 29), Vector2(2, 380), 0.43], [Vector2(1055, 86), Vector2(2, 275), -0.72]]:
		var crack := ColorRect.new()
		crack.position = crack_data[0]
		crack.size = crack_data[1]
		crack.rotation = crack_data[2]
		crack.color = Color(0.68, 0.78, 0.74, 0.2)
		crack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(crack)


func _move_astronaut(_delta: float) -> void:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1.0

	input = input.normalized()
	astronaut.velocity = Vector3(input.x * WALK_SPEED, 0.0, input.y * WALK_SPEED)
	astronaut.move_and_slide()
	astronaut.position.x = clamp(astronaut.position.x, -WORLD_X, WORLD_X)
	astronaut.position.z = clamp(astronaut.position.z, -WORLD_Z, WORLD_Z)
	if input.length() > 0.1:
		astronaut.rotation.y = lerp_angle(astronaut.rotation.y, atan2(input.x, input.y), 0.24)

	if carrying_shade:
		shade_panel.visible = true
		shade_panel.global_position = astronaut.global_position + Vector3(0.0, 1.45, 0.0)
		shade_panel.rotation = astronaut.rotation + Vector3(0.0, 0.0, -0.08)


func _update_camera() -> void:
	var focus := astronaut.global_position + Vector3(0.0, 0.55, 0.0)
	camera.global_position = focus + Vector3(8.8, 10.8, 10.5)
	camera.look_at(focus, Vector3.UP)


func _update_nearby_interactions() -> void:
	nearest_patch = ""
	nearest_harvest_cell = Vector2i(-1, -1)
	near_cache = not cache_opened and _flat_distance(astronaut.global_position, emergency_cache.global_position) < 1.45
	near_refuge = refuge_revealed and _flat_distance(astronaut.global_position, refuge_position) < 1.5
	var closest := 1.75
	for id in patches:
		var patch: Dictionary = patches[id]
		var distance := _flat_distance(astronaut.global_position, patch["node"].global_position)
		if distance < closest:
			closest = distance
			nearest_patch = id

	var player_world := Vector2(astronaut.global_position.x, astronaut.global_position.z)
	var player_cell: Vector2i = ecology.world_to_cell(player_world)
	var fruit_distance := 1.15
	for y in range(maxi(0, player_cell.y - 1), mini(EcologyGridModel.HEIGHT, player_cell.y + 2)):
		for x in range(maxi(0, player_cell.x - 1), mini(EcologyGridModel.WIDTH, player_cell.x + 2)):
			var sample: Dictionary = ecology.cell_snapshot(x, y)
			if sample["fruiting"] < 0.055:
				continue
			var cell_world: Vector2 = ecology.world_position(x, y)
			var distance := player_world.distance_to(cell_world)
			if distance < fruit_distance:
				fruit_distance = distance
				nearest_harvest_cell = Vector2i(x, y)

	var panel_distance := _flat_distance(astronaut.global_position, shade_panel.global_position)
	if near_cache:
		prompt_label.text = "E  open blinking emergency cache"
	elif nearest_harvest_cell.x >= 0:
		prompt_label.text = "E  harvest fungal fruiting body     Z  eat carried food"
	elif not carrying_shade and not shade_placed and panel_distance < 1.55:
		prompt_label.text = "E  pick up loose shade panel"
	elif carrying_shade and nearest_patch == "crust":
		prompt_label.text = "F  scan     SPACE  water     E  place shade panel"
	elif nearest_patch != "":
		if scanner_recovered:
			prompt_label.text = "F  scan     SPACE  commit one water dose"
		else:
			prompt_label.text = "The film is unusual, but bare eyes reveal little."
	elif near_refuge:
		prompt_label.text = "F  scan the bare depression     SPACE  commit water here"
	elif carrying_shade:
		prompt_label.text = "Carry the panel to a place where shade might change conditions."
	elif not scanner_recovered:
		prompt_label.text = "The wreck's blinking cache may contain usable instruments."
	else:
		prompt_label.text = "Look for surfaces that seem almost—but not quite—alive."


func _update_exposure(delta: float) -> void:
	var at_wreck := _flat_distance(astronaut.global_position, Vector3(-5.4, 0.0, -3.1)) < 2.55
	if at_wreck:
		exposure = max(0.0, exposure - delta * 2.4)
	elif _near_thriving_moss():
		exposure = min(100.0, exposure + delta * 0.14)
	else:
		exposure = min(100.0, exposure + delta * 0.42)


func _update_hunger(delta: float) -> void:
	hunger = min(100.0, hunger + delta * 0.28)


func _update_ecology(delta: float) -> void:
	for id in patches:
		var patch: Dictionary = patches[id]
		if patch["state"] != "wet" and patch["state"] != "awakening":
			continue

		patch["age"] += delta
		if not patch["shade"] and patch["age"] >= 1.25:
			patch["state"] = "failed"
			_set_patch_color(id, Color("77766e"))
			if nearest_patch == id:
				_set_status("The wet color collapses. A sharp amber residue spreads at the edges; this site changed the water's effect.")
		elif patch["shade"] and patch["state"] == "wet" and patch["age"] >= 1.25:
			patch["state"] = "awakening"
			_set_patch_color(id, Color("4f8259"), Color("244d2b"))
			_add_sprouts(id)
			if nearest_patch == id:
				_set_status("Fine green threads lift. Dust sticks to damp edges instead of blowing away.")
		elif patch["shade"] and patch["state"] == "awakening" and patch["age"] >= 4.0:
			patch["state"] = "thriving"
			_set_patch_color(id, Color("62b56f"), Color("347841"))
			_add_moisture_halo(id)
			_add_discovery("Moss analogue — active; retains local moisture")
			if nearest_patch == id:
				_set_status("The moss holds a living sheen. The scanner adds its first living record. Something watches from the ridge.")
			presence_root.visible = true


func _update_ecology_grid(delta: float) -> void:
	if not ecology_started:
		ecology_step_accumulator = 0.0
		return
	ecology_step_accumulator += delta
	while ecology_step_accumulator >= ECOLOGY_STEP_SECONDS:
		ecology_step_accumulator -= ECOLOGY_STEP_SECONDS
		ecology.step()
		_refresh_ecology_visuals()
		var state: Dictionary = ecology.summary()
		if not moss_spread_announced and state["moss_cells"] >= 5:
			moss_spread_announced = true
			_add_discovery("Moss spread — follows connected cool, moist cells")
			_set_status("Living green crosses the square cell boundaries. The moss is spreading beyond the watered point.")
		if not fungus_announced and state["fungus_cells"] >= 2:
			fungus_announced = true
			_add_discovery("Fungus — awakens in wet dead biomass; releases nutrients")
			_set_status("Pale violet threads appear beneath older moss. Dead material falls as nearby nutrient readings rise.")
		if not fruiting_announced and state["fruiting_cells"] >= 2:
			fruiting_announced = true
			_add_discovery("Fungal fruiting body — edible; depends on wet nutrient-rich mycelium")
			_set_status("Amber fruiting bodies rise from the violet network. The scanner marks their tissue as edible.")


func _update_grazer(delta: float) -> void:
	if not grazer_awake:
		var dormant_state: Dictionary = ecology.summary()
		if dormant_state["moss_cells"] >= 7 and dormant_state["fungus_cells"] >= 3 and dormant_state["fruiting_cells"] >= 2:
			grazer_awake = true
			grazer_root.scale = Vector3.ONE * 1.35
			grazer_body.material_override = _material(Color("76d2bd"), 0.58, Color("237563"))
			grazer_head.material_override = _material(Color("f2c36d"), 0.48, Color("8f571c"))
			grazer_label.visible = true
			grazer_glow.visible = true
			_add_discovery("Grazer — wakes above biomass threshold; eats moss and returns nutrients")
			_set_status("A stone-like shell unfolds into a small grazer. It turns toward the strongest moss signal.")
			disturbance_state = "warning"
			disturbance_timer = 14.0
		return

	grazer_root.position = grazer_root.position.lerp(grazer_target_position, minf(delta * 4.2, 1.0))
	grazer_step_timer -= delta
	if grazer_step_timer > 0.0:
		return
	grazer_step_timer = 1.05

	var best_cell := grazer_cell
	var best_score := -1.0
	for offset in [Vector2i.ZERO, Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var candidate: Vector2i = grazer_cell + offset
		if candidate.x < 0 or candidate.x >= EcologyGridModel.WIDTH or candidate.y < 0 or candidate.y >= EcologyGridModel.HEIGHT:
			continue
		var sample: Dictionary = ecology.cell_snapshot(candidate.x, candidate.y)
		var score: float = sample["moss"] + sample["fruiting"] * 0.18 - sample["toxicity"] * 0.42
		if score > best_score:
			best_score = score
			best_cell = candidate

	if best_score < 0.015:
		var scent_cell := _strongest_grazer_food_cell()
		if scent_cell != grazer_cell:
			best_cell = grazer_cell + Vector2i(signi(scent_cell.x - grazer_cell.x), signi(scent_cell.y - grazer_cell.y))
		else:
			grazer_failed_to_feed += 1
			if grazer_failed_to_feed == 4:
				_set_status("The grazer finds no viable moss. Its movement slows; this ecological trajectory cannot support it.")
			return

	grazer_failed_to_feed = 0
	grazer_cell = best_cell
	var target_world: Vector2 = ecology.world_position(grazer_cell.x, grazer_cell.y)
	grazer_target_position = Vector3(target_world.x, 0.28, target_world.y)
	if grazer_root.position.distance_to(grazer_target_position) > 0.01:
		grazer_root.look_at(grazer_target_position, Vector3.UP)
	ecology.graze_cell(grazer_cell)
	_refresh_ecology_visuals()


func _strongest_grazer_food_cell() -> Vector2i:
	var strongest_cell := grazer_cell
	var strongest_score := 0.015
	for y in range(EcologyGridModel.HEIGHT):
		for x in range(EcologyGridModel.WIDTH):
			var sample: Dictionary = ecology.cell_snapshot(x, y)
			var score: float = sample["moss"] + sample["fruiting"] * 0.18 - sample["toxicity"] * 0.42
			if score > strongest_score:
				strongest_score = score
				strongest_cell = Vector2i(x, y)
	return strongest_cell


func _update_disturbance(delta: float) -> void:
	if disturbance_state == "quiet" or disturbance_state == "passed":
		return
	if disturbance_state == "warning":
		disturbance_timer -= delta
		if disturbance_timer <= 9.0 and not refuge_revealed:
			_reveal_presence_nudge()
		if disturbance_timer <= 0.0:
			disturbance_state = "active"
			disturbance_timer = 0.0
			disturbance_column = 0
			dust_front.visible = true
			_add_discovery("Heat-and-dust front — dries cells and carries toxicity eastward")
			_set_status("The heat-and-dust front enters the basin. Living cover slows moisture loss where bare cells cannot.")
		return

	disturbance_timer += delta
	var desired_column := mini(int(disturbance_timer / 0.42), EcologyGridModel.WIDTH - 1)
	while disturbance_column <= desired_column and disturbance_column < EcologyGridModel.WIDTH:
		ecology.apply_dust_front(disturbance_column)
		disturbance_column += 1
		_refresh_ecology_visuals()
	if disturbance_column < EcologyGridModel.WIDTH:
		var front_world: Vector2 = ecology.world_position(disturbance_column, int(EcologyGridModel.HEIGHT / 2))
		dust_front.position.x = front_world.x
	else:
		dust_front.visible = false
		disturbance_state = "passed"
		_set_status("The front passes. Some bare cells are hot and toxic; connected moss and fungus begin recovering from retained moisture and nutrients.")


func _reveal_presence_nudge() -> void:
	refuge_revealed = true
	refuge_marker.visible = true
	ecology.reveal_subsurface_refuge(Vector2(refuge_position.x, refuge_position.z))
	presence_root.visible = true
	presence_target = refuge_position + Vector3(0.0, 1.15, 0.0)
	_set_status("As the wind rises, the Presence leaves the ridge and hovers over an apparently bare depression. It offers no instruction.")


func _refresh_ecology_visuals() -> void:
	for y in range(EcologyGridModel.HEIGHT):
		for x in range(EcologyGridModel.WIDTH):
			var index: int = y * EcologyGridModel.WIDTH + x
			var sample: Dictionary = ecology.cell_snapshot(x, y)
			var color := Color("46433d")
			color = color.lerp(Color("31515a"), clamp(sample["moisture"] * 0.52, 0.0, 0.5))
			color = color.lerp(Color("9a7240"), clamp(sample["toxicity"] * 0.32, 0.0, 0.3))
			color = color.lerp(Color("81553d"), clamp(sample["dead_biomass"] * 1.8, 0.0, 0.72))
			color = color.lerp(Color("4fa45e"), clamp(sample["moss"] * 1.45, 0.0, 0.9))
			color = color.lerp(Color("c064d3"), clamp(sample["fungus"] * 3.2, 0.0, 0.96))
			color = color.lerp(Color("efb34f"), clamp(sample["fruiting"] * 4.0, 0.0, 0.98))
			var material := StandardMaterial3D.new()
			material.albedo_color = color
			material.roughness = 0.9
			if sample["fungus"] >= 0.035:
				material.emission_enabled = true
				material.emission = Color("7b2c89") * min(sample["fungus"] * 2.4, 0.85)
				material.emission_energy_multiplier = 1.15
			ecology_cells[index].material_override = material
			if sample["fruiting"] >= 0.055:
				ecology_cells[index].position.y = 0.19
			elif sample["fungus"] >= 0.012:
				ecology_cells[index].position.y = 0.14
			elif sample["moss"] >= 0.03 or sample["dead_biomass"] >= 0.035:
				ecology_cells[index].position.y = 0.105
			else:
				ecology_cells[index].position.y = 0.012


func _scan_nearby_patch() -> void:
	if not scanner_recovered:
		_set_status("The astronaut needs the scientific kit from the emergency cache before local conditions can be compared.")
		return
	if near_refuge:
		var refuge_cell: Dictionary = ecology.sample_world(Vector2(refuge_position.x, refuge_position.z))
		scanner_title.text = "FIELD SCANNER  /  BARE DEPRESSION"
		scanner_readout.text = (
			"SUBSURFACE MOISTURE  %02d%%\n" % roundi(refuge_cell["moisture"] * 100.0)
			+ "SURFACE             %d C\n" % roundi(-8.0 + refuge_cell["temperature"] * 66.0)
			+ "TOXICITY            %02d%%\n" % roundi(refuge_cell["toxicity"] * 100.0)
			+ "DORMANT BIO TRACE   %02d%%\n\n" % roundi(refuge_cell["dormant_moss"] * 100.0)
			+ "The Presence indicated this place, not an action."
		)
		_add_discovery("Subsurface refuge — moist, cooler, dormant trace present")
		_set_status("The bare depression hides moisture below the scanner's normal surface range. The Presence waits without instructing.")
		return
	if nearest_patch == "":
		_set_status("The scanner finds no local biological trace. Move closer to an unusual surface.")
		return

	var patch: Dictionary = patches[nearest_patch]
	patch["scanned"] = true
	var state_text: String = patch["state"].to_upper()
	var patch_position: Vector3 = patch["node"].global_position
	var cell: Dictionary = ecology.sample_world(Vector2(patch_position.x, patch_position.z))
	var moisture_percent := roundi(cell["moisture"] * 100.0)
	var surface_celsius := roundi(-8.0 + cell["temperature"] * 66.0)
	var toxicity_percent := roundi(cell["toxicity"] * 100.0)
	var cell_life := "MOSS %02d%%  DEAD %02d%%  FUNGUS %02d%%  FRUIT %02d%%" % [
		roundi(cell["moss"] * 100.0),
		roundi(cell["dead_biomass"] * 100.0),
		roundi(cell["fungus"] * 100.0),
		roundi(cell["fruiting"] * 100.0)
	]
	if nearest_patch == "hollow":
		_add_discovery("Dormant moss analogue — sheltered trace")
		scanner_title.text = "FIELD SCANNER  /  SHELTERED FILM"
		scanner_readout.text = (
			"BIO TRACE     %s\n" % state_text
			+ "MOISTURE      %02d%%\n" % moisture_percent
			+ "SURFACE       %d C\n" % surface_celsius
			+ "TOXICITY      %02d%% / confidence 62%%\n" % toxicity_percent
			+ cell_life + "\n\n"
			+ _scanner_consequence_text(patch)
		)
		_set_status("The cracked screen cannot name the organism, but the hollow retains moisture and stays cool.")
	else:
		_add_discovery("Dormant moss analogue — exposed trace")
		scanner_title.text = "FIELD SCANNER  /  SUN-STRUCK FILM"
		scanner_readout.text = (
			"BIO TRACE     %s\n" % state_text
			+ "MOISTURE      %02d%%\n" % moisture_percent
			+ "SURFACE       %d C%s\n" % [surface_celsius, " / shaded" if patch["shade"] else " / direct heat"]
			+ "TOXICITY      %02d%% / amber band\n" % toxicity_percent
			+ cell_life + "\n\n"
			+ _scanner_consequence_text(patch)
		)
		if patch["state"] == "failed":
			_add_discovery("Amber toxicity — increases with surface heat")
			_set_status("The failed patch is evidence: water vanished as surface heat and the toxicity band rose together.")
		elif patch["shade"]:
			_add_discovery("Shade — lowers heat and slows moisture loss")
			_set_status("The panel changed two readings at once: heat falls and moisture loss slows.")
		else:
			_set_status("This film resembles the sheltered trace, but heat, moisture, and toxicity differ sharply.")


func _water_nearby_patch() -> void:
	if not cache_opened:
		_set_status("No usable water is on hand. The blinking emergency cache may still be intact.")
		return
	if near_refuge:
		if water_doses <= 0:
			_set_status("No water remains to test the Presence's indicated refuge.")
			return
		water_doses -= 1
		ecology_started = true
		ecology.add_water(Vector2(refuge_position.x, refuge_position.z), 0.72, 1.4)
		_set_status("Water sinks into the bare depression instead of flashing away. The Presence watches the cells, not the astronaut.")
		return
	if nearest_patch == "":
		_set_status("Water must be committed at a specific patch, not poured from a distance.")
		return
	if water_doses <= 0:
		_set_status("No water remains. Restart to test another hypothesis.")
		return

	var patch: Dictionary = patches[nearest_patch]
	if patch["state"] == "wet" or patch["state"] == "awakening" or patch["state"] == "thriving":
		_set_status("This patch is already responding. Watch it or compare the other site.")
		return

	water_doses -= 1
	ecology_started = true
	patch["state"] = "wet"
	patch["age"] = 0.0
	var patch_position: Vector3 = patch["node"].global_position
	ecology.add_water(Vector2(patch_position.x, patch_position.z))
	_set_patch_color(nearest_patch, Color("3e6653"), Color("18372d"))
	if patch["shade"]:
		_set_status("The film darkens with a dry crackle. Water remains pooled between its cells.")
	else:
		_set_status("The film darkens—but water beads, hisses, and starts flashing away in the heat.")


func _interact() -> void:
	if near_cache:
		_open_emergency_cache()
		return
	if nearest_harvest_cell.x >= 0:
		_harvest_fruiting()
		return
	_interact_with_shade()


func _harvest_fruiting() -> void:
	var world: Vector2 = ecology.world_position(nearest_harvest_cell.x, nearest_harvest_cell.y)
	var harvested: int = ecology.harvest_world(world)
	if harvested <= 0:
		_set_status("The fruiting body is not mature enough to harvest.")
		return
	fresh_food += harvested
	_refresh_ecology_visuals()
	_set_status("The astronaut harvests one fresh fungal fruit. The cell loses some fungus and nutrients; repeated harvests could break the cycle.")


func _open_emergency_cache() -> void:
	if cache_opened:
		return
	cache_opened = true
	scanner_recovered = true
	water_doses = 3
	ration_packs = 2
	emergency_cache.material_override = _material(Color("4e483e"), 0.92)
	var beacon := get_node_or_null("CacheBeacon") as OmniLight3D
	if beacon != null:
		beacon.light_energy = 0.18
	scanner_title.text = "CRACKED FIELD SCANNER  /  ONLINE"
	scanner_readout.text = "NO LOCAL SAMPLE\n\nSensor status: moisture and temperature available; toxicity confidence degraded."
	_update_discovery_readout()
	_set_status("The cache holds a cracked Field Scanner, three water doses, and two ration packs. Water is both survival margin and ecological possibility.")


func _use_water_for_survival() -> void:
	if not cache_opened:
		_set_status("The astronaut's personal water remains locked in the emergency cache.")
		return
	if water_doses <= 0:
		_set_status("No water remains for the astronaut or the ecosystem.")
		return
	if exposure < 8.0:
		_set_status("Suit reserves are still comfortable. Drinking now would spend ecological possibility for little gain.")
		return
	water_doses -= 1
	exposure = max(0.0, exposure - 32.0)
	_set_status("One shared water dose becomes personal survival margin. The ecosystem now has fewer possible interventions.")


func _eat_food() -> void:
	if hunger < 9.0:
		_set_status("The astronaut is not hungry enough to justify consuming food.")
		return
	if fresh_food > 0:
		fresh_food -= 1
		hunger = max(0.0, hunger - 34.0)
		_set_status("The first renewable food replaces a finite ration. Its ecological source must remain healthy to feed the astronaut again.")
		return
	if ration_packs > 0:
		ration_packs -= 1
		hunger = max(0.0, hunger - 42.0)
		_set_status("A finite ration buys time but creates no living replacement.")
		return
	_set_status("No carried food remains. The ecosystem is now the only path to another meal.")


func _interact_with_shade() -> void:
	if carrying_shade and nearest_patch == "crust":
		carrying_shade = false
		shade_placed = true
		shade_panel.global_position = patches["crust"]["node"].global_position + Vector3(0.0, 1.15, 0.0)
		shade_panel.rotation = Vector3(0.0, 0.18, -0.04)
		patches["crust"]["shade"] = true
		var crust_position: Vector3 = patches["crust"]["node"].global_position
		ecology.add_shade(Vector2(crust_position.x, crust_position.z))
		_set_status("The panel cuts the direct sun. The surface begins cooling, but lost water does not return.")
		return

	if not carrying_shade and not shade_placed and _flat_distance(astronaut.global_position, shade_panel.global_position) < 1.55:
		carrying_shade = true
		_set_status("The astronaut lifts the loose panel. It is awkward but light enough to reposition.")
		return

	if carrying_shade:
		_set_status("The panel needs a deliberate site. The sun-struck film is the clearest candidate.")
	else:
		_set_status("There is nothing here to handle.")


func _update_interface() -> void:
	if cache_opened:
		water_label.text = "WATER %d     RATIONS %d     FRESH FOOD %d" % [water_doses, ration_packs, fresh_food]
	else:
		water_label.text = "SUPPLIES  — emergency cache sealed"
	var exposure_state := "grace period"
	if exposure >= 22.0:
		exposure_state = "noticeable"
	if exposure >= 55.0:
		exposure_state = "return to shelter soon"
	if _near_thriving_moss():
		exposure_state = "moss microclimate slows exposure"
	exposure_label.text = "SUIT EXPOSURE  %02d%%  /  %s" % [roundi(exposure), exposure_state]
	var hunger_state := "fed"
	if hunger >= 45.0:
		hunger_state = "meal needed soon"
	if hunger >= 75.0:
		hunger_state = "survival pressure"
	hunger_label.text = "HUNGER  %02d%%  /  %s" % [roundi(hunger), hunger_state]
	var field_seconds := int(field_time * 12.0)
	time_label.text = "FIELD TIME  %02d:%02d  /  ecological response accelerated" % [field_seconds / 60, field_seconds % 60]
	var ecosystem: Dictionary = ecology.summary()
	ecosystem_label.text = "CELLS  moss %d  fungus %d  fruit %d  dead %d   GRAZER %s   tick %d" % [
		ecosystem["moss_cells"], ecosystem["fungus_cells"], ecosystem["fruiting_cells"], ecosystem["dead_cells"], "awake" if grazer_awake else "dormant", ecosystem["tick"]
	]
	match disturbance_state:
		"quiet":
			weather_label.text = "WEATHER  still / no active disturbance"
		"warning":
			weather_label.text = "WEATHER  heat-and-dust front approaching in %02ds" % ceili(disturbance_timer)
		"active":
			weather_label.text = "WEATHER  HEAT-AND-DUST FRONT crossing basin"
		_:
			weather_label.text = "WEATHER  front passed / recovery in progress"


func _scanner_consequence_text(patch: Dictionary) -> String:
	match patch["state"]:
		"wet":
			return "CHANGE: water registered; outcome unresolved"
		"awakening":
			return "CHANGE: filaments active; local cooling begins"
		"thriving":
			return "CHANGE: living cover retains local moisture"
		"failed":
			return "CHANGE: water lost; amber residue increased"
		_:
			return "CHANGE: no active metabolism detected"


func _create_patch(id: String, label_text: String, position: Vector3, color: Color, shade: bool) -> Dictionary:
	var root := Node3D.new()
	root.name = id.capitalize() + "MossPatch"
	root.position = position
	add_child(root)

	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.05
	mesh.bottom_radius = 1.12
	mesh.height = 0.07
	mesh.radial_segments = 48
	disc.mesh = mesh
	disc.material_override = _material(color, 0.96)
	root.add_child(disc)

	_create_world_label(label_text, position + Vector3(0.0, 0.3, 0.0), Color("f0ead5"), 0.0055)
	return {
		"node": root,
		"mesh": disc,
		"state": "dormant",
		"age": 0.0,
		"shade": shade,
		"scanned": false,
		"sprouts": false,
		"halo": false
	}


func _set_patch_color(id: String, color: Color, emission := Color(0.0, 0.0, 0.0, 1.0)) -> void:
	var patch: Dictionary = patches[id]
	patch["mesh"].material_override = _material(color, 0.82, emission)


func _add_sprouts(id: String) -> void:
	var patch: Dictionary = patches[id]
	if patch["sprouts"]:
		return
	patch["sprouts"] = true
	for index in range(11):
		var sprout := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.065
		mesh.height = 0.16
		sprout.mesh = mesh
		sprout.material_override = _material(Color("73bd6f"), 0.72, Color("244f2a"))
		var angle := float(index) * 2.399
		var radius := 0.18 + float(index % 4) * 0.18
		sprout.position = Vector3(cos(angle) * radius, 0.09, sin(angle) * radius)
		patch["node"].add_child(sprout)


func _add_moisture_halo(id: String) -> void:
	var patch: Dictionary = patches[id]
	if patch["halo"]:
		return
	patch["halo"] = true
	var halo := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.48
	mesh.bottom_radius = 1.55
	mesh.height = 0.025
	mesh.radial_segments = 48
	halo.mesh = mesh
	var halo_material := StandardMaterial3D.new()
	halo_material.albedo_color = Color(0.12, 0.34, 0.3, 0.48)
	halo_material.roughness = 0.68
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.material_override = halo_material
	halo.position.y = -0.012
	patch["node"].add_child(halo)
	patch["node"].move_child(halo, 0)


func _add_discovery(entry: String) -> void:
	if entry in discoveries:
		return
	discoveries.append(entry)
	_update_discovery_readout()


func _update_discovery_readout() -> void:
	if discovery_readout == null:
		return
	if not scanner_recovered:
		discovery_readout.text = "DISCOVERY RECORD\n— unavailable —"
		return
	if discoveries.is_empty():
		discovery_readout.text = "DISCOVERY RECORD\n— no species or relationships catalogued —"
		return
	var lines: Array[String] = ["DISCOVERY RECORD"]
	var start := maxi(0, discoveries.size() - 6)
	if start > 0:
		lines.append("• … %d earlier records" % start)
	for index in range(start, discoveries.size()):
		lines.append("• " + discoveries[index])
	discovery_readout.text = "\n".join(lines)


func _update_presence() -> void:
	if not presence_root.visible:
		return
	var pulse := Time.get_ticks_msec() / 520.0
	var drift_target := Vector3(presence_target.x, presence_root.position.y, presence_target.z)
	presence_root.position = presence_root.position.lerp(drift_target, 0.025)
	presence_root.position.y = presence_target.y + sin(pulse) * 0.13


func _create_box(position: Vector3, size: Vector3, color: Color, rotation := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = _material(color, 0.76)
	instance.position = position
	instance.rotation = rotation
	add_child(instance)
	return instance


func _create_cylinder(position: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.78
	mesh.bottom_radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.material_override = _material(color, 0.9)
	instance.position = position
	add_child(instance)
	return instance


func _create_rock(position: Vector3, scale_value: float, color := Color("666b67")) -> void:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = scale_value
	mesh.height = scale_value * 1.35
	rock.mesh = mesh
	rock.material_override = _material(color, 0.93)
	rock.position = position
	rock.scale = Vector3(1.25, 0.58, 0.9)
	rock.rotation.y = position.x * 0.31
	add_child(rock)


func _create_world_label(text: String, position: Vector3, color: Color, pixel_size: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.font_size = 42
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 9
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _material(color: Color, roughness: float, emission := Color(0.0, 0.0, 0.0, 1.0)) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission.r + emission.g + emission.b > 0.01:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.25
	return material


func _set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message


func _near_thriving_moss() -> bool:
	for id in patches:
		var patch: Dictionary = patches[id]
		if patch["state"] == "thriving" and _flat_distance(astronaut.global_position, patch["node"].global_position) < 2.25:
			return true
	return false


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
