extends Node3D

# THROWAWAY PROTOTYPE.
# This scene tests whether a first Field Experiment teaches itself through
# movement, local comparison, scarce intervention, and ecological feedback.

const WALK_SPEED := 4.3
const WORLD_X := 8.8
const WORLD_Z := 6.2

var astronaut: CharacterBody3D
var camera: Camera3D
var water_doses := 3
var exposure := 0.0
var patches: Dictionary = {}
var nearest_patch := ""
var shade_panel: MeshInstance3D
var shade_panel_home := Vector3(-5.4, 0.32, 2.7)
var carrying_shade := false
var shade_placed := false
var presence_root: Node3D

var water_label: Label
var exposure_label: Label
var prompt_label: Label
var status_label: Label
var scanner_card: PanelContainer
var scanner_title: Label
var scanner_readout: Label


func _ready() -> void:
	_build_world()
	_build_astronaut()
	_build_patches()
	_build_presence()
	_build_interface()
	_set_status("Nothing here looks alive. Two mineral films catch the light differently.")


func _physics_process(delta: float) -> void:
	_move_astronaut(delta)
	_update_camera()
	_update_nearby_interactions()
	_update_exposure(delta)
	_update_ecology(delta)
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
			_interact_with_shade()
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

	# The sheltered hollow reads through shade, darker ground, and surrounding stones.
	_create_box(Vector3(-2.8, 1.25, -1.55), Vector3(3.2, 0.16, 1.55), Color("555b59"), Vector3(0.0, -0.18, -0.08))
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


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var title := Label.new()
	title.position = Vector2(24, 18)
	title.text = "FIRST RAIN  /  THROWAWAY FIRST INTERACTION"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("e9b36e"))
	canvas.add_child(title)

	water_label = Label.new()
	water_label.position = Vector2(24, 47)
	water_label.add_theme_font_size_override("font_size", 22)
	canvas.add_child(water_label)

	exposure_label = Label.new()
	exposure_label.position = Vector2(24, 78)
	exposure_label.add_theme_font_size_override("font_size", 14)
	exposure_label.add_theme_color_override("font_color", Color("b9c1be"))
	canvas.add_child(exposure_label)

	var controls := Label.new()
	controls.position = Vector2(24, 606)
	controls.text = "WASD / ARROWS  move     F  scan     SPACE  water     E  handle panel     R  restart"
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
	scanner_card.size = Vector2(360, 218)
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
	scanner_title.text = "CRACKED FIELD SCANNER"
	scanner_title.add_theme_font_size_override("font_size", 16)
	scanner_title.add_theme_color_override("font_color", Color("83d1b2"))
	stack.add_child(scanner_title)

	scanner_readout = Label.new()
	scanner_readout.text = "NO LOCAL SAMPLE\n\nMove close to an unusual surface and press F."
	scanner_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scanner_readout.add_theme_font_size_override("font_size", 14)
	scanner_readout.add_theme_color_override("font_color", Color("c4d4cd"))
	stack.add_child(scanner_readout)

	# A visible crack makes the instrument's damage legible without corrupting readings.
	for crack_data in [[Vector2(1015, 29), Vector2(2, 202), 0.43], [Vector2(1055, 86), Vector2(2, 105), -0.72]]:
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
	var closest := 1.75
	for id in patches:
		var patch: Dictionary = patches[id]
		var distance := _flat_distance(astronaut.global_position, patch["node"].global_position)
		if distance < closest:
			closest = distance
			nearest_patch = id

	var panel_distance := _flat_distance(astronaut.global_position, shade_panel.global_position)
	if not carrying_shade and not shade_placed and panel_distance < 1.55:
		prompt_label.text = "E  pick up loose shade panel"
	elif carrying_shade and nearest_patch == "crust":
		prompt_label.text = "F  scan     SPACE  water     E  place shade panel"
	elif nearest_patch != "":
		prompt_label.text = "F  scan     SPACE  commit one water dose"
	elif carrying_shade:
		prompt_label.text = "Carry the panel to a place where shade might change conditions."
	else:
		prompt_label.text = "Look for surfaces that seem almost—but not quite—alive."


func _update_exposure(delta: float) -> void:
	var at_wreck := _flat_distance(astronaut.global_position, Vector3(-5.4, 0.0, -3.1)) < 2.55
	if at_wreck:
		exposure = max(0.0, exposure - delta * 2.4)
	else:
		exposure = min(100.0, exposure + delta * 0.42)


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
			if nearest_patch == id:
				_set_status("The moss holds a living sheen. Nearby ground is visibly darker and cooler. Something watches from the ridge.")
		presence_root.visible = true


func _scan_nearby_patch() -> void:
	if nearest_patch == "":
		_set_status("The scanner finds no local biological trace. Move closer to an unusual surface.")
		return

	var patch: Dictionary = patches[nearest_patch]
	patch["scanned"] = true
	var state_text: String = patch["state"].to_upper()
	if nearest_patch == "hollow":
		scanner_title.text = "FIELD SCANNER  /  SHELTERED FILM"
		scanner_readout.text = (
			"BIO TRACE     %s\n" % state_text
			+ "MOISTURE      18%%  / retained\n"
			+ "SURFACE       11 C below ambient\n"
			+ "TOXICITY      low band / confidence 62%%\n\n"
			+ _scanner_consequence_text(patch)
		)
		_set_status("The cracked screen cannot name the organism, but the hollow retains moisture and stays cool.")
	else:
		scanner_title.text = "FIELD SCANNER  /  SUN-STRUCK FILM"
		var heat_text := "46 C / direct heat" if not patch["shade"] else "24 C / falling under shade"
		var toxicity_text := "high amber band" if patch["state"] == "failed" else "amber band / rises with heat"
		scanner_readout.text = (
			"BIO TRACE     %s\n" % state_text
			+ "MOISTURE      2%%  / rapid loss\n"
			+ "SURFACE       %s\n" % heat_text
			+ "TOXICITY      %s\n\n" % toxicity_text
			+ _scanner_consequence_text(patch)
		)
		if patch["state"] == "failed":
			_set_status("The failed patch is evidence: water vanished as surface heat and the toxicity band rose together.")
		elif patch["shade"]:
			_set_status("The panel changed two readings at once: heat falls and moisture loss slows.")
		else:
			_set_status("This film resembles the sheltered trace, but heat, moisture, and toxicity differ sharply.")


func _water_nearby_patch() -> void:
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
	patch["state"] = "wet"
	patch["age"] = 0.0
	_set_patch_color(nearest_patch, Color("3e6653"), Color("18372d"))
	if patch["shade"]:
		_set_status("The film darkens with a dry crackle. Water remains pooled between its cells.")
	else:
		_set_status("The film darkens—but water beads, hisses, and starts flashing away in the heat.")


func _interact_with_shade() -> void:
	if carrying_shade and nearest_patch == "crust":
		carrying_shade = false
		shade_placed = true
		shade_panel.global_position = patches["crust"]["node"].global_position + Vector3(0.0, 1.15, 0.0)
		shade_panel.rotation = Vector3(0.0, 0.18, -0.04)
		patches["crust"]["shade"] = true
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
	water_label.text = "WATER  %d / 3 shared doses" % water_doses
	var exposure_state := "grace period"
	if exposure >= 22.0:
		exposure_state = "noticeable"
	if exposure >= 55.0:
		exposure_state = "return to shelter soon"
	exposure_label.text = "SUIT EXPOSURE  %02d%%  /  %s" % [roundi(exposure), exposure_state]


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
		"sprouts": false
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
	if emission.r + emission.g + emission.b > 0.01:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.25
	return material


func _set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
