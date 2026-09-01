extends Node3D

# THROWAWAY PROTOTYPE.
# This scene tests whether a first Field Experiment teaches itself through
# movement, local comparison, scarce intervention, and ecological feedback.

const WALK_SPEED := 1.9
const GRAZER_MOVE_SPEED := 0.38
const WORLD_MIN_X := -9.0
const WORLD_MAX_X := 41.0
const WORLD_MIN_Z := -7.0
const WORLD_MAX_Z := 27.0
const ECOLOGY_STEP_SECONDS := 0.34
const VOLUNTARY_RECOVERY_SECONDS := 2.0
const FORCED_RECOVERY_SECONDS := 10.0
const LAST_WATER_HOLD_SECONDS := 0.75
const FIELD_TIME_SCALE := 12.0
const EXPOSED_EXPOSURE_RATE := 0.105
const MOSS_EXPOSURE_RATE := 0.035
const REWATER_MOISTURE_THRESHOLD := 0.16
# Forty-five hunger points marks a meal. At 12× displayed field time this
# takes eight in-world hours, supporting roughly three meals per field day.
const HUNGER_RATE := 0.01875
const EcologyGridModel = preload("res://ecology_grid.gd")
const EvidenceRecorder = preload("res://evidence_recorder.gd")
const AnimalSimulation = preload("res://animal_simulation.gd")
const WeatherSimulation = preload("res://weather_simulation.gd")

var astronaut: CharacterBody3D
var camera: Camera3D
var ecology
var animal_simulation
var weather_simulation
var evidence
var evidence_debug_open := false
var evidence_debug_selection := 0
var evidence_panel: PanelContainer
var evidence_readout: Label
var last_intervention_event_id := ""
var grazer_wake_event_id := ""
var grazer_bite_event_id := ""
var disturbance_event_id := ""
var ecology_cells: Array[MeshInstance3D] = []
var ecology_step_accumulator := 0.0
var ecology_started := false
var moss_spread_announced := false
var fungus_announced := false
var fruiting_announced := false
var rhizome_announced := false
var canopy_announced := false
var aquatic_announced := false
var sulfur_announced := false
var water_doses := 0
var ration_packs := 0
var fresh_food := 0
var hunger := 34.0
var exposure := 0.0
var field_time := 0.0
var field_review_open := false
var forced_recoveries := 0
var last_water_hold_active := false
var last_water_hold_timer := 0.0
var last_water_hold_target := ""
var scanner_recovered := false
var cache_opened := false
var discoveries: Array[String] = []
var scanner_samples: Dictionary = {}
var last_scanned_site := ""
var analysis_lens_enabled := false
var lens_anchor_cell := Vector2i(-1, -1)
var scan_pulse: MeshInstance3D
var scan_pulse_timer := 0.0
var patches: Dictionary = {}
var nearest_patch := ""
var near_cache := false
var nearest_harvest_cell := Vector2i(-1, -1)
var near_refuge := false
var refuge_position := Vector3(37.0, 0.03, 23.0)
var refuge_marker: Node3D
var refuge_revealed := false
var refuge_watered := false
var emergency_cache: MeshInstance3D
var shade_panel: MeshInstance3D
var shade_preview: MeshInstance3D
var shade_panel_home := Vector3(-5.4, 0.32, 2.7)
var carrying_shade := false
var shade_placed := false
var shade_placed_cell := Vector2i(-1, -1)
var clump_marker: MeshInstance3D
var carried_clump: Dictionary = {}
var reservoir_established := false
var reclaimer_intact := true
var reclaimer_hold_active := false
var reclaimer_hold_timer := 0.0
var presence_root: Node3D
var presence_target := Vector3(24.0, 1.3, -3.5)
var presence_signal_ring: MeshInstance3D
var astronaut_signal_ring: MeshInstance3D
var astronaut_signal_beam: MeshInstance3D
var presence_signal_audio: AudioStreamPlayer
var presence_signal_elapsed := 0.0
var presence_signal_duration := 0.0
var presence_signal_interval := 0.4
var presence_signal_primary := Vector3.ZERO
var presence_signal_secondary := Vector3.ZERO
var presence_signal_has_secondary := false
var astronaut_signal_timer := 0.0
var presence_focus_id := ""
var last_astronaut_signal_id := ""
var last_astronaut_signal_position := Vector3.ZERO
var last_astronaut_signal_timer := 0.0
var refuge_signal_acknowledged := false

var grazer_root: Node3D
var grazer_body: MeshInstance3D
var grazer_head: MeshInstance3D
var grazer_label: Label3D
var grazer_glow: OmniLight3D
var grazer_awake := false
var grazer_cell := Vector2i.ZERO
var grazer_target_position := Vector3.ZERO
var grazer_step_timer := 0.0
var grazer_state := "dormant"
var grazer_manure_announced := false
var animal_markers: Dictionary = {}
var animal_roles_announced: Dictionary = {}
var colony_ant_stream_root: Node3D
var colony_ant_markers: Array[MeshInstance3D] = []
var habitat_search_species: Array[String] = []
var habitat_search_cursor := 0
var habitat_search_scores: Dictionary = {}
var habitat_search_best: Dictionary = {}
var habitat_search_snapshot: Dictionary = {}
var first_rain_announced := false

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
var zone_label: Label
var visited_zones: Dictionary = {}
var scanner_before_survey := ""


func _ready() -> void:
	_build_world()
	_build_spatial_landmarks()
	_build_ecology_grid()
	_build_astronaut()
	_build_patches()
	_build_presence()
	_build_presence_signals()
	_build_refuge()
	_build_grazer()
	_build_ecological_animal_markers()
	_build_disturbance()
	_build_scan_pulse()
	_build_interface()
	_build_evidence_debugger()
	evidence = EvidenceRecorder.new()
	evidence.begin_run(1, _evidence_snapshot())
	_set_status("The crash has stopped. The ship is dead, but an emergency cache still blinks beneath the broken wing.")


func _physics_process(delta: float) -> void:
	if field_review_open or evidence_debug_open:
		_update_interface()
		_update_evidence_debugger()
		return
	field_time += delta
	_move_astronaut(delta)
	_update_camera()
	_update_nearby_interactions()
	_update_exposure(delta)
	_update_hunger(delta)
	_update_ecology(delta)
	_update_ecology_grid(delta)
	_update_grazer(delta)
	_update_colony_worker_visual()
	_update_disturbance(delta)
	_update_presence()
	_update_presence_signals(delta)
	_update_scan_pulse(delta)
	_update_last_water_hold(delta)
	_update_reclaimer_hold(delta)
	if exposure >= 100.0:
		_force_recovery()
	_update_interface()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_E and not event.pressed:
		reclaimer_hold_active = false
		reclaimer_hold_timer = 0.0
		return
	if event is InputEventKey and event.keycode == KEY_SPACE and not event.pressed:
		last_water_hold_active = false
		last_water_hold_timer = 0.0
		last_water_hold_target = ""
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_F:
			_scan_nearby_patch()
		KEY_V:
			_toggle_analysis_lens()
		KEY_C:
			_signal_to_presence()
		KEY_SPACE:
			_request_water_intervention()
		KEY_E:
			_interact()
		KEY_T:
			_transplant_living_clump()
		KEY_Q:
			_use_water_for_survival()
		KEY_Z:
			_eat_food()
		KEY_R:
			get_tree().reload_current_scene()
		KEY_J:
			_toggle_field_review()
		KEY_F9:
			_toggle_evidence_debugger()
		KEY_BRACKETLEFT:
			_select_earlier_evidence()
		KEY_BRACKETRIGHT:
			_select_later_evidence()


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
	ground_body.position = Vector3(16.0, 0.0, 10.0)
	add_child(ground_body)

	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(52.0, 36.0)
	ground_mesh.mesh = plane
	ground_mesh.material_override = _material(Color("3e4241"), 0.92)
	ground_body.add_child(ground_mesh)

	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(52.0, 0.2, 36.0)
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
	for position in [Vector3(14.4, 0.18, 5.1), Vector3(17.8, 0.24, 0.6), Vector3(18.4, 0.18, 5.0)]:
		_create_rock(position, 0.42, Color("8d8068"))
	var vent := _create_cylinder(Vector3(17.0, 0.34, 3.0), 0.42, 0.9, Color("765b45"))
	vent.name = "ToxicVent"
	var vent_light := OmniLight3D.new()
	vent_light.position = Vector3(17.0, 0.9, 3.0)
	vent_light.light_color = Color("e5a557")
	vent_light.light_energy = 0.9
	vent_light.omni_range = 2.4
	add_child(vent_light)

	shade_panel = _create_box(shade_panel_home, Vector3(1.45, 0.09, 0.85), Color("839199"), Vector3(0.0, 0.22, -0.08))
	shade_panel.name = "LooseShadePanel"
	shade_preview = _create_cylinder(shade_panel_home, 4.0, 0.025, Color(0.25, 0.75, 0.72, 0.28))
	shade_preview.name = "ShadeFootprintPreview"
	shade_preview.visible = false
	clump_marker = _create_cylinder(shade_panel_home, 0.34, 0.22, Color("4fa45e"))
	clump_marker.name = "CarriedLivingClump"
	clump_marker.visible = false
	_create_world_label("LOOSE WRECK PANEL", shade_panel_home + Vector3(0.0, 0.45, 0.0), Color("e4e8e4"), 0.0055)


func _build_ecology_grid() -> void:
	ecology = EcologyGridModel.new()
	animal_simulation = AnimalSimulation.new(ecology, 1)
	weather_simulation = WeatherSimulation.new(1701)
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


func _build_spatial_landmarks() -> void:
	# Greybox geography: colored landforms and labels communicate gradients and
	# route structure without pretending to be production environment art.
	_create_world_label("WRECK SHELTER / NORTHWEST RIM", Vector3(-5.4, 1.65, -4.8), Color("d9c49a"), 0.006)
	_create_world_label("SHELTERED HOLLOW", Vector3(-2.7, 0.75, -1.55), Color("9fc6a5"), 0.006)
	_create_world_label("EXPOSED TOXIC SHELF", Vector3(16.0, 0.8, 3.0), Color("e1ac70"), 0.006)
	_create_world_label("DRY DRAINAGE SPINE", Vector3(12.0, 0.55, 11.0), Color("81aeb5"), 0.006)
	_create_world_label("DOWNSTREAM RECOVERY POCKET", Vector3(37.0, 0.7, 23.0), Color("78c7b4"), 0.006)
	for point in [Vector3(2.0, 0.025, 1.0), Vector3(7.0, 0.025, 5.0), Vector3(12.0, 0.025, 9.0), Vector3(17.0, 0.025, 12.0), Vector3(22.0, 0.025, 15.0), Vector3(27.0, 0.025, 18.0), Vector3(32.0, 0.025, 21.0)]:
		_create_box(point, Vector3(4.8, 0.035, 2.2), Color("4d6263"), Vector3(0.0, -0.62, 0.0))
	# Outer-loop landmarks remain visible from the wreck while local conditions
	# stay hidden behind shelves and stone clusters.
	for point in [Vector3(1.0, 0.45, -4.5), Vector3(9.0, 0.55, -4.0), Vector3(22.0, 0.65, -1.0), Vector3(31.0, 0.55, 7.0), Vector3(38.0, 0.5, 15.0)]:
		_create_rock(point, 0.85, Color("78807a"))
	_create_box(Vector3(16.0, 0.16, 3.0), Vector3(8.0, 0.28, 7.0), Color("706653"), Vector3(0.0, 0.08, 0.0))
	_create_box(Vector3(37.0, 0.08, 23.0), Vector3(7.0, 0.12, 6.0), Color("3e5650"), Vector3.ZERO)


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
		Vector3(16.0, 0.34, 3.0),
		Color("8c826c"),
		false
	)


func _build_presence() -> void:
	presence_root = Node3D.new()
	presence_root.name = "DistantPresence"
	presence_root.position = Vector3(24.0, 1.3, -3.5)
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


func _build_presence_signals() -> void:
	presence_signal_ring = _create_signal_ring("PresenceSignalRing", Color("65d9cd"), 0.03)
	astronaut_signal_ring = _create_signal_ring("AstronautSignalRing", Color("9fd5ee"), 0.045)

	astronaut_signal_beam = MeshInstance3D.new()
	astronaut_signal_beam.name = "AstronautSignalBeam"
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(0.035, 0.035, 1.0)
	astronaut_signal_beam.mesh = beam_mesh
	astronaut_signal_beam.material_override = _signal_material(Color("9fd5ee"), 0.68)
	astronaut_signal_beam.visible = false
	add_child(astronaut_signal_beam)

	presence_signal_audio = AudioStreamPlayer.new()
	presence_signal_audio.name = "PresenceSignalAudio"
	presence_signal_audio.volume_db = -8.0
	add_child(presence_signal_audio)


func _create_signal_ring(node_name: String, color: Color, height: float) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.72
	mesh.bottom_radius = 0.78
	mesh.height = height
	mesh.radial_segments = 48
	ring.mesh = mesh
	ring.material_override = _signal_material(color, 0.52)
	ring.visible = false
	add_child(ring)
	return ring


func _signal_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.45
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


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
	grazer_cell = ecology.world_to_cell(Vector2(6.0, 6.0))
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


func _build_ecological_animal_markers() -> void:
	var specifications := {
		"grazer:2": ["GRAZER / JUVENILE", Color("8edbc3")],
		"colony:1": ["EUSOCIAL HIVE", Color("dc9a52")],
		"vector:1": ["FLYING VECTOR", Color("e9d36a")],
		"engineer:1": ["WETLAND ENGINEER", Color("5da7c9")],
		"predator:1": ["PREDATOR", Color("d76767")]
	}
	for stable_id in specifications:
		var specification: Array = specifications[stable_id]
		var marker := Node3D.new()
		marker.name = "AnimalMarker_" + String(stable_id).replace(":", "_")
		marker.visible = false
		var body := MeshInstance3D.new()
		if stable_id == "colony:1":
			var hive_mesh := CylinderMesh.new()
			hive_mesh.top_radius = 0.18
			hive_mesh.bottom_radius = 0.34
			hive_mesh.height = 0.24
			hive_mesh.radial_segments = 12
			body.mesh = hive_mesh
		else:
			var mesh := SphereMesh.new()
			mesh.radius = 0.2
			mesh.height = 0.36
			body.mesh = mesh
		body.material_override = _material(specification[1], 0.58, specification[1].darkened(0.45))
		marker.add_child(body)
		var label := Label3D.new()
		label.text = specification[0]
		label.position.y = 0.58
		label.font_size = 26
		label.pixel_size = 0.0042
		label.modulate = specification[1]
		label.outline_size = 7
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.add_child(label)
		add_child(marker)
		animal_markers[stable_id] = marker
	colony_ant_stream_root = Node3D.new()
	colony_ant_stream_root.name = "ColonyWorkerStream"
	colony_ant_stream_root.visible = false
	add_child(colony_ant_stream_root)
	for worker_index in range(7):
		var ant := MeshInstance3D.new()
		var ant_mesh := SphereMesh.new()
		ant_mesh.radius = 0.045
		ant_mesh.height = 0.075
		ant.mesh = ant_mesh
		ant.scale = Vector3(1.35, 0.55, 0.75)
		ant.material_override = _material(Color("e4a85b"), 0.42, Color("75401f"))
		colony_ant_stream_root.add_child(ant)
		colony_ant_markers.append(ant)


func _build_disturbance() -> void:
	dust_front = _create_box(Vector3(-7.0, 1.15, 10.0), Vector3(0.5, 2.3, 34.0), Color("b97845"))
	dust_front.name = "HeatDustFront"
	var dust_material := StandardMaterial3D.new()
	dust_material.albedo_color = Color(0.78, 0.39, 0.16, 0.34)
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_front.material_override = dust_material
	dust_front.visible = false


func _build_scan_pulse() -> void:
	scan_pulse = MeshInstance3D.new()
	scan_pulse.name = "LocalScannerPulse"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.72
	mesh.bottom_radius = 0.78
	mesh.height = 0.025
	mesh.radial_segments = 48
	scan_pulse.mesh = mesh
	scan_pulse.visible = false
	add_child(scan_pulse)


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var title := Label.new()
	title.position = Vector2(24, 18)
	title.text = "FIRST RAIN  /  HABITAT COLONIZATION PROTOTYPE"
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

	zone_label = Label.new()
	zone_label.position = Vector2(24, 198)
	zone_label.add_theme_font_size_override("font_size", 14)
	zone_label.add_theme_color_override("font_color", Color("8ab8c0"))
	canvas.add_child(zone_label)

	var controls := Label.new()
	controls.position = Vector2(24, 606)
	controls.text = "WASD move   E interact/recover   T transplant   F scan   C signal   J records   V lens   SPACE water   Q drink   Z eat   F9 evidence"
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
	scanner_card.size = Vector2(360, 535)
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


func _build_evidence_debugger() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	evidence_panel = PanelContainer.new()
	evidence_panel.position = Vector2(120, 70)
	evidence_panel.size = Vector2(910, 535)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.055, 0.97)
	style.border_color = Color("5eb6a4")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	evidence_panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(evidence_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	evidence_panel.add_child(margin)
	evidence_readout = Label.new()
	evidence_readout.add_theme_font_size_override("font_size", 15)
	evidence_readout.add_theme_color_override("font_color", Color("c7e5dc"))
	evidence_readout.text = "EVIDENCE RECORDER STARTING"
	margin.add_child(evidence_readout)
	evidence_panel.visible = false


func _toggle_evidence_debugger() -> void:
	evidence_debug_open = not evidence_debug_open
	evidence_debug_selection = 0
	evidence_panel.visible = evidence_debug_open
	_update_evidence_debugger()


func _select_earlier_evidence() -> void:
	if not evidence_debug_open or evidence == null:
		return
	evidence_debug_selection = mini(evidence_debug_selection + 1, maxi(0, evidence.events.size() - 1))
	_update_evidence_debugger()


func _select_later_evidence() -> void:
	if not evidence_debug_open:
		return
	evidence_debug_selection = maxi(0, evidence_debug_selection - 1)
	_update_evidence_debugger()


func _update_evidence_debugger() -> void:
	if not evidence_debug_open or evidence == null:
		return
	evidence_readout.text = "\n".join(evidence.debug_view(evidence_debug_selection)) + "\n\n[ / ] select event     F9 close (simulation paused)"


func _evidence_snapshot() -> Dictionary:
	return {
		"field_time": field_time,
		"ecology": ecology.full_snapshot(),
		"supplies": {"water": water_doses, "rations": ration_packs, "fresh_food": fresh_food},
		"carried_clump": carried_clump.duplicate(true),
		"astronaut": {"position": astronaut.position, "hunger": hunger, "exposure": exposure},
		"patches": {
			"hollow": {"state": patches["hollow"]["state"], "shade": patches["hollow"]["shade"]},
			"crust": {"state": patches["crust"]["state"], "shade": patches["crust"]["shade"]}
		},
		"grazer": {"awake": grazer_awake, "state": grazer_state, "cell": grazer_cell},
		"animals": animal_simulation.snapshot(),
		"weather": weather_simulation.snapshot(),
		"disturbance": disturbance_state
	}


func _record_command(verb: String, target: String, facts := {}) -> String:
	var command_facts: Dictionary = facts.duplicate(true)
	command_facts["field_time"] = field_time
	command_facts["astronaut_position"] = astronaut.position
	return evidence.record_command(ecology.tick, verb, target, command_facts)


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
	astronaut.position.x = clamp(astronaut.position.x, WORLD_MIN_X, WORLD_MAX_X)
	astronaut.position.z = clamp(astronaut.position.z, WORLD_MIN_Z, WORLD_MAX_Z)
	visited_zones[_current_zone()] = true
	if input.length() > 0.1:
		astronaut.rotation.y = lerp_angle(astronaut.rotation.y, atan2(input.x, input.y), 0.24)
	if analysis_lens_enabled:
		var current_cell: Vector2i = ecology.world_to_cell(Vector2(astronaut.position.x, astronaut.position.z))
		if current_cell != lens_anchor_cell:
			lens_anchor_cell = current_cell
			_refresh_ecology_visuals()

	if carrying_shade:
		shade_panel.visible = true
		shade_panel.global_position = astronaut.global_position + Vector3(0.0, 1.45, 0.0)
		shade_panel.rotation = astronaut.rotation + Vector3(0.0, 0.0, -0.08)
		var preview_cell: Vector2i = ecology.world_to_cell(Vector2(astronaut.position.x, astronaut.position.z))
		var preview_world: Vector2 = ecology.world_position(preview_cell.x, preview_cell.y)
		shade_preview.position = Vector3(preview_world.x, 0.035, preview_world.y)
		shade_preview.visible = true
	elif shade_preview != null:
		shade_preview.visible = false
	if not carried_clump.is_empty():
		clump_marker.visible = true
		clump_marker.global_position = astronaut.global_position + Vector3(0.0, 1.25, 0.0)
		clump_marker.rotation = astronaut.rotation
	else:
		clump_marker.visible = false


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
	elif not carrying_shade and panel_distance < 1.55:
		prompt_label.text = "E  retrieve movable shade panel"
	elif carrying_shade:
		prompt_label.text = "E  place shade on this ecological cell  /  footprint shown"
	elif nearest_patch != "":
		if scanner_recovered:
			var nearby_patch: Dictionary = patches[nearest_patch]
			var nearby_position: Vector3 = nearby_patch["node"].global_position
			var nearby_sample: Dictionary = ecology.sample_world(Vector2(nearby_position.x, nearby_position.z))
			var established: bool = nearby_patch["state"] == "wet" or nearby_patch["state"] == "awakening" or nearby_patch["state"] == "thriving"
			if established and nearby_sample["moisture"] <= REWATER_MOISTURE_THRESHOLD:
				prompt_label.text = "F  scan     SPACE  rewater dry habitat"
			elif established:
				prompt_label.text = "F  scan     habitat moisture sufficient"
			else:
				prompt_label.text = "F  scan     SPACE  commit one water dose"
		else:
			prompt_label.text = "The film is unusual, but bare eyes reveal little."
	elif near_refuge:
		prompt_label.text = "E  refill one canister     F  scan reservoir" if reservoir_established else "F  scan the bare depression     SPACE  commit water here"
	elif cache_opened and _at_wreck() and water_doses == 0 and not reservoir_established and reclaimer_intact:
		prompt_label.text = "HOLD E  reclaim one emergency water / permanently slow recovery"
	elif cache_opened and _at_wreck() and exposure > 0.5:
		prompt_label.text = "E  recover at the wreck while the ecosystem continues"
	elif not scanner_recovered:
		prompt_label.text = "The wreck's blinking cache may contain usable instruments."
	else:
		prompt_label.text = "Look for surfaces that seem almost—but not quite—alive."
	var current_cell: Vector2i = ecology.world_to_cell(Vector2(astronaut.position.x, astronaut.position.z))
	var current_sample: Dictionary = ecology.cell_snapshot(current_cell.x, current_cell.y)
	if not carried_clump.is_empty():
		prompt_label.text += "     T  place carried %s clump" % String(carried_clump["resource"])
	elif not carrying_shade and (current_sample["moss"] >= 0.08 or current_sample["rhizome"] >= 0.025):
		prompt_label.text += "     T  lift living clump"
	if presence_root.visible:
		prompt_label.text += "     C  signal toward nearby subject"
	if last_water_hold_active:
		prompt_label.text = "HOLD SPACE  final water dose  %d%%" % roundi(100.0 * last_water_hold_timer / LAST_WATER_HOLD_SECONDS)
	if reclaimer_hold_active:
		prompt_label.text = "HOLD E  dismantle life-support reclaimer  %d%%" % roundi(100.0 * reclaimer_hold_timer / LAST_WATER_HOLD_SECONDS)


func _update_exposure(delta: float) -> void:
	if _at_wreck():
		return
	var hunger_multiplier := 1.0
	if hunger >= 75.0:
		hunger_multiplier = 1.6
	elif hunger >= 45.0:
		hunger_multiplier = 1.25
	var exposure_rate := MOSS_EXPOSURE_RATE if _near_thriving_moss() else EXPOSED_EXPOSURE_RATE
	exposure = min(100.0, exposure + delta * exposure_rate * hunger_multiplier)


func _update_hunger(delta: float) -> void:
	if _at_wreck():
		return
	hunger = min(100.0, hunger + delta * HUNGER_RATE)


func _at_wreck() -> bool:
	return _flat_distance(astronaut.global_position, Vector3(-5.4, 0.0, -3.1)) < 2.55


func _toggle_field_review() -> void:
	if not scanner_recovered:
		_set_status("The detailed record remains sealed in the emergency cache.")
		return
	field_review_open = not field_review_open
	last_water_hold_active = false
	if field_review_open:
		scanner_before_survey = scanner_readout.text
		scanner_title.text = "FIELD SCANNER  /  BASIN SURVEY"
		scanner_readout.text = _basin_survey_text()
	else:
		scanner_title.text = "CRACKED FIELD SCANNER  /  ONLINE"
		scanner_readout.text = scanner_before_survey
	scanner_card.modulate = Color("d9fff2") if field_review_open else Color.WHITE
	_set_status("The astronaut braces at the scanner and reconstructs the recorded evidence. Ecological time is paused." if field_review_open else "The scanner record closes. Field time resumes.")


func _current_zone() -> String:
	if _at_wreck():
		return "WRECK SHELTER"
	var position := Vector2(astronaut.position.x, astronaut.position.z)
	var zones := {
		"SHELTERED HOLLOW": Vector2(-2.7, -1.55),
		"EXPOSED TOXIC SHELF": Vector2(16.0, 3.0),
		"DOWNSTREAM RECOVERY POCKET": Vector2(37.0, 23.0),
		"DRY DRAINAGE SPINE": Vector2(18.0, 12.0)
	}
	var nearest := "DRY DRAINAGE SPINE"
	var nearest_distance := INF
	for zone in zones:
		var distance: float = position.distance_to(zones[zone])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = zone
	return nearest


func _basin_survey_text() -> String:
	var lines: Array[String] = ["VISITED ECOLOGICAL ZONES  /  last observed, not live"]
	for zone in ["WRECK SHELTER", "SHELTERED HOLLOW", "DRY DRAINAGE SPINE", "EXPOSED TOXIC SHELF", "DOWNSTREAM RECOVERY POCKET"]:
		lines.append(("• " + zone) if visited_zones.has(zone) else "• ?????  /  unvisited")
	lines.append("")
	lines.append("SHADE PANEL  " + ("last observed at cell %d,%d" % [shade_placed_cell.x, shade_placed_cell.y] if shade_placed else ("carried" if carrying_shade else "last observed near wreck")))
	lines.append("LIVING CLUMP  " + ("%s carried" % String(carried_clump.get("resource", "")) if not carried_clump.is_empty() else "none carried"))
	lines.append("Conditions may have changed since observation.")
	lines.append("No route or objective is inferred.")
	return "\n".join(lines)


func _request_water_intervention() -> void:
	if water_doses != 1 or (nearest_patch == "" and not near_refuge):
		_water_nearby_patch()
		return
	if last_water_hold_active:
		return
	last_water_hold_active = true
	last_water_hold_timer = 0.0
	last_water_hold_target = "refuge" if near_refuge else nearest_patch
	_set_status("This is the final carried water dose. Hold SPACE to commit it; release to keep it.")


func _update_last_water_hold(delta: float) -> void:
	if not last_water_hold_active:
		return
	var current_target := "refuge" if near_refuge else nearest_patch
	if not Input.is_key_pressed(KEY_SPACE) or current_target != last_water_hold_target:
		last_water_hold_active = false
		last_water_hold_timer = 0.0
		last_water_hold_target = ""
		return
	last_water_hold_timer += delta
	if last_water_hold_timer < LAST_WATER_HOLD_SECONDS:
		return
	last_water_hold_active = false
	last_water_hold_timer = 0.0
	last_water_hold_target = ""
	_water_nearby_patch()


func _recover_at_wreck(forced: bool) -> void:
	var before := _observed_recovery_state()
	var elapsed := FORCED_RECOVERY_SECONDS if forced or not reclaimer_intact else VOLUNTARY_RECOVERY_SECONDS
	var command_id := ""
	if not forced:
		command_id = _record_command("recover", "wreck", {"elapsed": elapsed})
	if forced:
		forced_recoveries += 1
		if carrying_shade:
			shade_placed_cell = ecology.world_to_cell(Vector2(astronaut.position.x, astronaut.position.z))
			var dropped_world: Vector2 = ecology.world_position(shade_placed_cell.x, shade_placed_cell.y)
			carrying_shade = false
			shade_placed = true
			shade_panel.position = Vector3(dropped_world.x, 0.18, dropped_world.y)
			ecology.place_equipment_shade(dropped_world)
		if not carried_clump.is_empty():
			var dropped_cell: Vector2i = ecology.world_to_cell(Vector2(astronaut.position.x, astronaut.position.z))
			_place_carried_clump(dropped_cell, true)
		astronaut.position = Vector3(-5.4, 0.05, -3.1)
		astronaut.velocity = Vector3.ZERO
	exposure = 0.0
	_advance_ecology_during_recovery(elapsed)
	var report := _recovery_report(before, _observed_recovery_state())
	var causes := [] if command_id == "" else [command_id]
	evidence.record_event(ecology.tick, "survival.forced_recovery" if forced else "survival.voluntary_recovery", "astronaut", causes, {"elapsed": elapsed, "observed_before": before, "observed_after": _observed_recovery_state()})
	evidence.checkpoint(ecology.tick, "recovery_boundary", _evidence_snapshot())
	if forced:
		_set_status("Suit emergency return: the astronaut wakes at the wreck after about two field minutes. " + report)
	else:
		_set_status("The astronaut deliberately recovers at the wreck while a few ecological moments pass. " + report)


func _force_recovery() -> void:
	last_water_hold_active = false
	_recover_at_wreck(true)


func _advance_ecology_during_recovery(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(ECOLOGY_STEP_SECONDS, remaining)
		field_time += step
		_update_ecology(step)
		_update_ecology_grid(step)
		_update_grazer(step)
		_update_disturbance(step)
		_update_presence()
		remaining -= step
	_refresh_ecology_visuals()


func _observed_recovery_state() -> Dictionary:
	var observed := {"weather": disturbance_state}
	for id in patches:
		if patches[id]["scanned"]:
			observed[id] = patches[id]["state"]
	if grazer_awake:
		observed["grazer"] = grazer_state
	return observed


func _recovery_report(before: Dictionary, after: Dictionary) -> String:
	var changes: Array[String] = []
	for key in after:
		if before.has(key) and before[key] != after[key]:
			changes.append("%s changed from %s to %s" % [String(key).replace("_", " "), before[key], after[key]])
	if changes.is_empty():
		return "Previously observed sites show no major state change."
	return "Scanner reconstruction: " + "; ".join(changes) + "."


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
			presence_root.visible = true
			_presence_focus(id, patch["node"].global_position)
			_set_status("The moss holds a living sheen. A flame leaves the ridge, settles beside it, and sends one narrow pulse through the green surface.")


func _update_ecology_grid(delta: float) -> void:
	if not ecology_started:
		ecology_step_accumulator = 0.0
		return
	ecology_step_accumulator += delta
	while ecology_step_accumulator >= ECOLOGY_STEP_SECONDS:
		ecology_step_accumulator -= ECOLOGY_STEP_SECONDS
		_seed_integrated_animals()
		var animal_events: Array[Dictionary] = animal_simulation.step()
		_handle_authoritative_animal_events(animal_events)
		var state: Dictionary = ecology.summary()
		var weather_events: Array[Dictionary] = weather_simulation.step(state)
		_handle_weather_events(weather_events)
		if weather_simulation.precipitation > 0.0:
			ecology.add_water(Vector2(16.0, 10.0), weather_simulation.precipitation * 0.04, 58.0)
		_refresh_ecology_visuals()
		_update_ecological_animal_markers()
		if not moss_spread_announced and state["moss_cells"] >= 5:
			moss_spread_announced = true
			var moss_causes := [] if last_intervention_event_id == "" else [last_intervention_event_id]
			evidence.record_event(ecology.tick, "ecology.moss_spread", "basin", moss_causes, state)
			_add_discovery("Moss spread — follows connected cool, moist cells")
			_set_status("Living green crosses the square cell boundaries. The moss is spreading beyond the watered point.")
		if not fungus_announced and state["fungus_cells"] >= 2:
			fungus_announced = true
			evidence.record_event(ecology.tick, "ecology.fungus_awakened", "basin", [], state)
			_add_discovery("Fungus — awakens in wet dead biomass; releases nutrients")
			_set_status("Pale violet threads appear beneath older moss. Dead material falls as nearby nutrient readings rise.")
		if not fruiting_announced and state["fruiting_cells"] >= 2:
			fruiting_announced = true
			evidence.record_event(ecology.tick, "ecology.fruiting_bodies", "basin", [], state)
			_add_discovery("Fungal fruiting body — edible; depends on wet nutrient-rich mycelium")
			_set_status("Amber fruiting bodies rise from the violet network. The scanner marks their tissue as edible.")
		if not rhizome_announced and state["rhizome_cells"] >= 2:
			rhizome_announced = true
			evidence.record_event(ecology.tick, "ecology.rhizome_established", "basin", [], state)
			_add_discovery("Rhizome mat — rooted forage; binds drainage sediment and competes for shallow water")
			_set_status("Blue-green ribbons root beneath the pioneer cover. Loose sediment holds while nearby shallow moisture falls.")
		if not canopy_announced and state["canopy_cells"] >= 1:
			canopy_announced = true
			evidence.record_event(ecology.tick, "ecology.canopy_established", "basin", [], state)
			_add_discovery("Canopy-former — deep-rooted shade, litter, transpiration, and atmospheric vapor")
			_set_status("A dark branching fan rises above the rooted mat. Its shade cools the soil while its crown releases moisture.")
		if not aquatic_announced and state["aquatic_cells"] >= 1:
			aquatic_announced = true
			evidence.record_event(ecology.tick, "ecology.aquatic_food_web", "basin", [], state)
			_add_discovery("Aquatic food web — producer bloom regulated by consumers and dissolved oxygen")
			_set_status("Turquoise cells gather in standing water. Smaller moving flecks graze the bloom instead of letting it grow unchecked.")
		if not sulfur_announced and state["total_volatile_sulfur"] >= 0.012:
			sulfur_announced = true
			evidence.record_event(ecology.tick, "ecology.volatile_sulfur_released", "basin", [], state)
			_add_discovery("Volatile sulfur analogue — aquatic microbial processing contributes material to the air")
			_set_status("The wetland releases a sharp airborne trace. The scanner separates sulfur precursor in water from volatile material above it.")


func _seed_integrated_animals() -> void:
	var arrivals := [
		["colony", "colony:1"],
		["vector", "vector:1"],
		["wetland_engineer", "engineer:1"]
	]
	if grazer_awake:
		arrivals.append(["grazer", "grazer:2"])
	if animal_simulation.agents.has("grazer:2"):
		arrivals.append(["predator", "predator:1"])
	var missing_species: Array[String] = []
	for arrival in arrivals:
		if not animal_simulation.agents.has(String(arrival[1])):
			missing_species.append(String(arrival[0]))
	if missing_species.is_empty():
		_reset_habitat_search()
		return
	var habitats := _continue_arrival_habitat_search(missing_species)
	if habitats.is_empty():
		return
	for arrival in arrivals:
		var species: String = arrival[0]
		var stable_id: String = arrival[1]
		if animal_simulation.agents.has(stable_id):
			continue
		var habitat: Dictionary = habitats.get(species, {})
		if habitat.is_empty():
			continue
		_register_ecological_role(species, stable_id, habitat)


func _continue_arrival_habitat_search(species: Array[String]) -> Dictionary:
	const CELLS_PER_ECOLOGY_TICK := 24
	if species.size() == 1 and species[0] == "predator":
		return {"predator": _best_predator_arrival_habitat()}
	if habitat_search_species != species or habitat_search_snapshot.is_empty():
		habitat_search_species = species.duplicate()
		habitat_search_cursor = 0
		habitat_search_scores.clear()
		habitat_search_best.clear()
		habitat_search_snapshot = ecology.full_snapshot()
		for candidate in species:
			if candidate != "predator":
				habitat_search_scores[candidate] = -1.0
	var cell_count: int = ecology.WIDTH * ecology.HEIGHT
	var end_cursor: int = mini(habitat_search_cursor + CELLS_PER_ECOLOGY_TICK, cell_count)
	for flat_index in range(habitat_search_cursor, end_cursor):
		var cell := Vector2i(flat_index % ecology.WIDTH, floori(float(flat_index) / float(ecology.WIDTH)))
		var evidence_by_radius := {}
		for candidate in habitat_search_scores:
			var radius := 3 if candidate == "vector" else 2
			if not evidence_by_radius.has(radius):
				evidence_by_radius[radius] = _local_habitat_evidence(cell, radius, candidate == "vector", habitat_search_snapshot)
			var evidence: Dictionary = evidence_by_radius[radius]
			var score := _species_habitat_score(candidate, evidence)
			if score > float(habitat_search_scores[candidate]):
				habitat_search_scores[candidate] = score
				habitat_search_best[candidate] = {"cell": cell, "score": score, "evidence": evidence}
	habitat_search_cursor = end_cursor
	if habitat_search_cursor < cell_count:
		return {}
	var completed := {}
	for candidate in species:
		if candidate == "predator":
			completed[candidate] = _best_predator_arrival_habitat()
		elif float(habitat_search_scores[candidate]) >= 0.0:
			completed[candidate] = habitat_search_best[candidate]
		else:
			completed[candidate] = {}
	_reset_habitat_search()
	return completed


func _reset_habitat_search() -> void:
	habitat_search_species.clear()
	habitat_search_cursor = 0
	habitat_search_scores.clear()
	habitat_search_best.clear()
	habitat_search_snapshot.clear()


func _best_arrival_habitat(species: String) -> Dictionary:
	return _best_arrival_habitats([species]).get(species, {})


func _best_arrival_habitats(species: Array[String]) -> Dictionary:
	var best_by_species := {}
	var best_scores := {}
	for candidate in species:
		if candidate == "predator":
			best_by_species[candidate] = _best_predator_arrival_habitat()
		else:
			best_scores[candidate] = -1.0
	var habitat_snapshot: Dictionary = ecology.full_snapshot()
	for y in range(ecology.HEIGHT):
		for x in range(ecology.WIDTH):
			var cell := Vector2i(x, y)
			var evidence_by_radius := {}
			for candidate in best_scores:
				var radius := 3 if candidate == "vector" else 2
				if not evidence_by_radius.has(radius):
					evidence_by_radius[radius] = _local_habitat_evidence(cell, radius, candidate == "vector", habitat_snapshot)
				var evidence: Dictionary = evidence_by_radius[radius]
				var score := _species_habitat_score(candidate, evidence)
				if score > float(best_scores[candidate]):
					best_scores[candidate] = score
					best_by_species[candidate] = {"cell": cell, "score": score, "evidence": evidence}
	for candidate in best_scores:
		if float(best_scores[candidate]) < 0.0:
			best_by_species[candidate] = {}
	return best_by_species


func _local_habitat_evidence(center: Vector2i, radius: int, include_flowering_topology := true, habitat_state: Dictionary = {}) -> Dictionary:
	var evidence := {
		"detritus": 0.0,
		"dry_detritus": 0.0,
		"forage": 0.0,
		"open_forage": 0.0,
		"nearby_cover": 0.0,
		"forage_cover_edges": 0,
		"surface_water": 0.0,
		"drainage_flow": 0.0,
		"plant_material": 0.0,
		"flowering": 0.0,
		"flowering_sources": 0,
		"flowering_clusters": 0,
		"flowering_separation": 0,
		"moisture": 0.0,
		"toxicity": 0.0,
		"weight": 0.0
	}
	var flowering_cells: Array[Vector2i] = []
	var open_forage_cells: Array[Vector2i] = []
	var cover_cells: Array[Vector2i] = []
	var dead_biomass_values: PackedFloat32Array = habitat_state.get("dead_biomass", ecology.dead_biomass)
	var moss_values: PackedFloat32Array = habitat_state.get("moss", ecology.moss)
	var rhizome_values: PackedFloat32Array = habitat_state.get("rhizome", ecology.rhizome)
	var canopy_values: PackedFloat32Array = habitat_state.get("canopy", ecology.canopy)
	var shade_values: PackedFloat32Array = habitat_state.get("shade", ecology.shade)
	var surface_water_values: PackedFloat32Array = habitat_state.get("surface_water", ecology.surface_water)
	var ground_bloom_values: PackedFloat32Array = habitat_state.get("ground_bloom", ecology.ground_bloom)
	var canopy_bloom_values: PackedFloat32Array = habitat_state.get("canopy_bloom", ecology.canopy_bloom)
	var moisture_values: PackedFloat32Array = habitat_state.get("moisture", ecology.moisture)
	var toxicity_values: PackedFloat32Array = habitat_state.get("toxicity", ecology.toxicity)
	for y in range(maxi(0, center.y - radius), mini(ecology.HEIGHT - 1, center.y + radius) + 1):
		for x in range(maxi(0, center.x - radius), mini(ecology.WIDTH - 1, center.x + radius) + 1):
			var cell := Vector2i(x, y)
			var index: int = y * ecology.WIDTH + x
			var distance := absi(x - center.x) + absi(y - center.y)
			var weight := 1.0 / float(distance + 1)
			var local_detritus: float = dead_biomass_values[index]
			var local_forage: float = moss_values[index] + rhizome_values[index]
			var local_cover: float = canopy_values[index] + shade_values[index]
			var local_surface_water: float = surface_water_values[index]
			var local_flowering: float = ground_bloom_values[index] + canopy_bloom_values[index]
			evidence["detritus"] += local_detritus * weight
			evidence["forage"] += local_forage * weight
			evidence["surface_water"] += local_surface_water * weight
			evidence["plant_material"] += (moss_values[index] + rhizome_values[index] + canopy_values[index]) * weight
			if include_flowering_topology:
				evidence["flowering"] += local_flowering * weight
			if local_detritus >= 0.03 and moisture_values[index] <= 0.2 and local_surface_water <= 0.03:
				evidence["dry_detritus"] += local_detritus * weight
			if local_forage >= 0.16 and canopy_values[index] < 0.06:
				evidence["open_forage"] += local_forage * weight
				open_forage_cells.append(cell)
			if local_cover >= 0.1:
				evidence["nearby_cover"] += local_cover * weight
				cover_cells.append(cell)
			evidence["drainage_flow"] += local_surface_water * _drainage_spine_affinity(cell) * weight
			if include_flowering_topology and local_flowering >= 0.025:
				evidence["flowering_sources"] += 1
				flowering_cells.append(cell)
			evidence["moisture"] += moisture_values[index] * weight
			evidence["toxicity"] += toxicity_values[index] * weight
			evidence["weight"] += weight
	evidence["moisture"] /= maxf(0.001, float(evidence["weight"]))
	evidence["toxicity"] /= maxf(0.001, float(evidence["weight"]))
	if include_flowering_topology:
		var flowering_topology := _flowering_topology(flowering_cells)
		evidence["flowering_clusters"] = flowering_topology["clusters"]
		evidence["flowering_separation"] = flowering_topology["separation"]
	for forage_cell in open_forage_cells:
		for cover_cell in cover_cells:
			var edge_distance := absi(forage_cell.x - cover_cell.x) + absi(forage_cell.y - cover_cell.y)
			if edge_distance >= 1 and edge_distance <= 3:
				evidence["forage_cover_edges"] += 1
	return evidence


func _flowering_topology(flowering_cells: Array[Vector2i]) -> Dictionary:
	var unvisited := {}
	for cell in flowering_cells:
		unvisited[cell] = true
	var clusters: Array[Array] = []
	while not unvisited.is_empty():
		var seed: Vector2i = unvisited.keys()[0]
		var frontier: Array[Vector2i] = [seed]
		var cluster: Array[Vector2i] = []
		unvisited.erase(seed)
		while not frontier.is_empty():
			var current: Vector2i = frontier.pop_back()
			cluster.append(current)
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = current + direction
				if unvisited.has(neighbor):
					unvisited.erase(neighbor)
					frontier.append(neighbor)
		clusters.append(cluster)
	var separation := 0
	for first_index in range(clusters.size()):
		for second_index in range(first_index + 1, clusters.size()):
			var closest_pair: int = ecology.WIDTH + ecology.HEIGHT
			for first_cell in clusters[first_index]:
				for second_cell in clusters[second_index]:
					closest_pair = mini(closest_pair, absi(first_cell.x - second_cell.x) + absi(first_cell.y - second_cell.y))
			separation = maxi(separation, closest_pair)
	return {"clusters": clusters.size(), "separation": separation}


func _drainage_spine_affinity(cell: Vector2i) -> float:
	var point: Vector2 = ecology.world_position(cell.x, cell.y)
	var spine := [
		Vector2(2.0, 1.0),
		Vector2(7.0, 5.0),
		Vector2(12.0, 9.0),
		Vector2(17.0, 12.0),
		Vector2(22.0, 15.0),
		Vector2(27.0, 18.0),
		Vector2(32.0, 21.0)
	]
	var closest_distance := INF
	for index in range(spine.size() - 1):
		var start: Vector2 = spine[index]
		var segment: Vector2 = spine[index + 1] - start
		var along := clampf((point - start).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
		closest_distance = minf(closest_distance, point.distance_to(start + segment * along))
	return 1.0 - clampf(closest_distance / 4.0, 0.0, 1.0)


func _species_habitat_score(species: String, evidence: Dictionary) -> float:
	var viability: float = maxf(0.0, 1.0 - float(evidence["toxicity"]))
	match species:
		"colony":
			if float(evidence["dry_detritus"]) < 0.42:
				return -1.0
			return float(evidence["dry_detritus"]) * viability
		"vector":
			if int(evidence["flowering_clusters"]) < 2 or int(evidence["flowering_separation"]) < 2 or float(evidence["flowering"]) < 0.1:
				return -1.0
			return float(evidence["flowering"]) * viability + float(evidence["flowering_separation"]) * 0.025
		"wetland_engineer":
			if float(evidence["drainage_flow"]) < 0.12 or float(evidence["plant_material"]) < 0.32:
				return -1.0
			return minf(float(evidence["drainage_flow"]), float(evidence["plant_material"])) * viability
		"grazer":
			if float(evidence["open_forage"]) < 0.65 or float(evidence["nearby_cover"]) < 0.1 or int(evidence["forage_cover_edges"]) < 1:
				return -1.0
			return minf(float(evidence["open_forage"]), float(evidence["nearby_cover"]) * 2.0) * viability
	return -1.0


func _best_predator_arrival_habitat() -> Dictionary:
	var prey_cells: Array[Vector2i] = []
	for stable_id in animal_simulation.agents:
		var agent: Dictionary = animal_simulation.agent_state(stable_id)
		if not agent.is_empty() and bool(agent["alive"]) and String(agent["species"]) == "grazer":
			prey_cells.append(agent["cell"])
	if prey_cells.size() < 2:
		return {}
	var best_cell := Vector2i.ZERO
	var best_score := -1.0
	for y in range(ecology.HEIGHT):
		for x in range(ecology.WIDTH):
			var cell := Vector2i(x, y)
			var score := 0.0
			for prey_cell in prey_cells:
				score += 1.0 / float(absi(prey_cell.x - cell.x) + absi(prey_cell.y - cell.y) + 1)
			if score > best_score:
				best_score = score
				best_cell = cell
	return {"cell": best_cell, "score": best_score, "evidence": {"living_grazers": prey_cells.size()}}


func _register_ecological_role(species: String, stable_id: String, habitat: Dictionary) -> void:
	var cell: Vector2i = habitat["cell"]
	if not animal_simulation.register_agent(species, stable_id, {"cell": cell, "hunger": 0.35, "body_biomass": 0.8}):
		return
	animal_roles_announced[stable_id] = true
	var arrival_observations := {
		"colony": "Eusocial hive — a fixed earthen mound forms beside dry Detritus; tiny workers begin tracing one route outward",
		"vector": "Flying animal — repeated crossings begin between nearby blossoms",
		"wetland_engineer": "Large wetland animal — tracks gather beside shallow water and nearby plant growth",
		"grazer": "Second grazer — another animal settles into a concentrated forage patch",
		"predator": "Predator — fresh tracks converge on the grazers' range"
	}
	_add_discovery(arrival_observations.get(species, "New animal activity appears in a changed habitat"))
	evidence.record_event(ecology.tick, "organism.%s_established" % species, stable_id, [], {
		"cell": cell,
		"habitat_score": habitat["score"],
		"habitat_evidence": habitat["evidence"]
	})


func _update_ecological_animal_markers() -> void:
	if colony_ant_stream_root != null:
		colony_ant_stream_root.visible = false
	for stable_id in animal_markers:
		var marker: Node3D = animal_markers[stable_id]
		var agent: Dictionary = animal_simulation.agent_state(stable_id)
		if agent.is_empty() or not bool(agent["alive"]):
			marker.visible = false
			continue
		marker.visible = true
		var cell: Vector2i = agent.get("home_cell", agent["cell"]) if String(agent["species"]) == "colony" else agent["cell"]
		var world: Vector2 = ecology.world_position(cell.x, cell.y)
		var height := 0.62 if String(agent["species"]) == "vector" else 0.25
		marker.position = marker.position.lerp(Vector3(world.x, height, world.y), 0.45)
		var label: Label3D = marker.get_child(1)
		label.text = String(label.text).split(" / ")[0] + " / " + String(agent["state"]).to_upper()
		if stable_id == "colony:1":
			_update_colony_worker_stream(agent)


func _update_colony_worker_stream(agent: Dictionary) -> void:
	if colony_ant_stream_root == null:
		return
	var home_cell: Vector2i = agent.get("home_cell", agent["cell"])
	var worker_cell: Vector2i = agent.get("worker_cell", home_cell)
	var phase := String(agent.get("worker_phase", "idle"))
	colony_ant_stream_root.visible = phase != "idle" or worker_cell != home_cell
	if not colony_ant_stream_root.visible:
		return
	var home_world: Vector2 = ecology.world_position(home_cell.x, home_cell.y)
	var worker_world: Vector2 = ecology.world_position(worker_cell.x, worker_cell.y)
	var direction := worker_world - home_world
	var lateral := Vector2(-direction.y, direction.x).normalized() * 0.08 if direction.length() > 0.01 else Vector2.ZERO
	var flow_offset := fmod(float(Time.get_ticks_msec()) / 4200.0, 1.0)
	for worker_index in range(colony_ant_markers.size()):
		var ant := colony_ant_markers[worker_index]
		var progress := fmod(flow_offset + float(worker_index) / float(colony_ant_markers.size()), 1.0)
		if phase == "returning":
			progress = 1.0 - progress
		var trail_point := home_world.lerp(worker_world, progress) + lateral * (0.5 if worker_index % 2 == 0 else -0.5)
		var target := Vector3(trail_point.x, 0.16, trail_point.y)
		ant.position = target


func _update_colony_worker_visual() -> void:
	if animal_simulation == null or not animal_simulation.agents.has("colony:1"):
		if colony_ant_stream_root != null:
			colony_ant_stream_root.visible = false
		return
	var colony: Dictionary = animal_simulation.agent_state("colony:1")
	if colony.is_empty() or not bool(colony["alive"]):
		colony_ant_stream_root.visible = false
		return
	_update_colony_worker_stream(colony)


func _handle_weather_events(events: Array[Dictionary]) -> void:
	for event in events:
		match String(event["taxonomy"]):
			"weather.dust":
				if disturbance_state == "quiet" or disturbance_state == "passed":
					disturbance_state = "warning"
					disturbance_timer = 8.0
					disturbance_event_id = evidence.record_event(ecology.tick, "environment.dust_window_detected", "regional_atmosphere", [], weather_simulation.snapshot())
					_set_status("Pressure falls while hot crosswinds lift dust from bare ground. The suit projects only a short warning; the flame turns toward the advancing haze.")
			"weather.first_rain":
				if first_rain_announced:
					continue
				first_rain_announced = true
				evidence.record_event(ecology.tick, "environment.first_rain", "crash_basin", [], weather_simulation.snapshot())
				evidence.checkpoint(ecology.tick, "first_rain", _evidence_snapshot())
				_add_discovery("First Rain — sustained natural precipitation after biological vapor, cloud-active material, and a favorable regional weather window converge")
				_set_status("Rain reaches the basin floor and keeps falling. The restored life helped prepare the air and retain what lands here—but the regional weather supplied the opening.")


func _update_grazer(delta: float) -> void:
	if not grazer_awake:
		var dormant_state: Dictionary = ecology.summary()
		if dormant_state["moss_cells"] >= 7 and dormant_state["fungus_cells"] >= 3 and dormant_state["fruiting_cells"] >= 2:
			grazer_awake = true
			animal_simulation.register_agent("grazer", "grazer:1", {"cell": grazer_cell, "hunger": 1.0})
			grazer_wake_event_id = evidence.record_event(ecology.tick, "organism.grazer_awakened", "grazer:1", [], dormant_state)
			_set_grazer_state("seeking")
			grazer_root.scale = Vector3.ONE * 1.35
			grazer_body.material_override = _material(Color("76d2bd"), 0.58, Color("237563"))
			grazer_head.material_override = _material(Color("f2c36d"), 0.48, Color("8f571c"))
			grazer_label.visible = true
			grazer_glow.visible = true
			_add_discovery("Grazer — wakes above biomass threshold; eats moss and returns nutrients")
			_presence_focus("grazer", grazer_root.position)
			_set_status("A stone-like shell unfolds into a small grazer. The flame moves beside it and repeats the same single pulse used at the moss.")
			evidence.checkpoint(ecology.tick, "episode_boundary", _evidence_snapshot())
		return
	var authoritative: Dictionary = animal_simulation.agent_state("grazer:1")
	if authoritative.is_empty() or not bool(authoritative["alive"]):
		_set_grazer_state("dead")
		return
	grazer_cell = authoritative["cell"]
	_set_grazer_state(authoritative["state"])
	var target_world: Vector2 = ecology.world_position(grazer_cell.x, grazer_cell.y)
	grazer_target_position = Vector3(target_world.x, 0.28, target_world.y)
	grazer_root.position = grazer_root.position.move_toward(grazer_target_position, GRAZER_MOVE_SPEED * delta)
	if grazer_root.position.distance_to(grazer_target_position) > 0.01:
		grazer_root.look_at(grazer_target_position, Vector3.UP)


func _set_grazer_state(next_state: String) -> void:
	if grazer_state == next_state:
		return
	grazer_state = next_state
	if grazer_label != null:
		grazer_label.text = "GRAZER / " + next_state.to_upper()




func _handle_authoritative_animal_events(events: Array[Dictionary]) -> void:
	for event in events:
		match String(event["taxonomy"]):
			"organism.moss_consumed", "organism.rhizome_consumed":
				var facts: Dictionary = event["facts"]
				var cell: Vector2i = facts["cell"]
				grazer_bite_event_id = evidence.record_event(ecology.tick, "organism.moss_grazed", "cell:%d,%d" % [cell.x, cell.y], [grazer_wake_event_id], {"amount": facts["amount"]})
				_set_status("The grazer takes one measured bite, then leaves the moss to recover while it digests.")
			"organism.material_deposited":
				var facts: Dictionary = event["facts"]
				if event["subject"] != "grazer:1":
					continue
				var cell: Vector2i = facts["cell"]
				var manure_causes := [] if grazer_bite_event_id == "" else [grazer_bite_event_id]
				evidence.record_event(ecology.tick, "organism.manure_deposited", "cell:%d,%d" % [cell.x, cell.y], manure_causes, {"amount": facts["amount"]})
				if not grazer_manure_announced:
					grazer_manure_announced = true
					_add_discovery("Grazer manure — moves nutrients from feeding sites into new ecological cells")
					_set_status("The grazer deposits dark pellets away from the moss it ate. Local dead biomass and nutrient readings rise.")
			"organism.patch_pollinated":
				var facts: Dictionary = event["facts"]
				evidence.record_event(ecology.tick, "organism.plant_pollinated", event["subject"], [], facts)
				if not animal_roles_announced.has("pollination_observed"):
					animal_roles_announced["pollination_observed"] = true
					_add_discovery("Plant pollination — flying vectors carry pollen between ground-cover flowers and canopy blossoms")
					_set_status("The flying vector moves between two flowering plant patches. The scanner detects transferred pollen; no fungal tissue is involved.")
			"organism.fungal_spores_distributed":
				var facts: Dictionary = event["facts"]
				evidence.record_event(ecology.tick, "organism.fungal_spores_distributed", event["subject"], [], facts)
				if not animal_roles_announced.has("spore_dispersal_observed"):
					animal_roles_announced["spore_dispersal_observed"] = true
					_add_discovery("Fungal spore dispersal — animals carry spores from fruiting bodies into wet detritus; this is not pollination")
					_set_status("A vector leaves a fungal fruiting body dusted with spores, then sheds them over wet dead matter. The scanner records dispersal, not pollination.")
			"organism.colony_plant_returned":
				var facts: Dictionary = event["facts"]
				evidence.record_event(ecology.tick, "organism.colony_plant_returned", event["subject"], [], facts)
				if not animal_roles_announced.has("colony_transport_observed"):
					animal_roles_announced["colony_transport_observed"] = true
					_add_discovery("Eusocial worker trail — small plant loads travel back to one fixed hive and enter its Detritus cycle")
					_set_status("A thin worker stream returns to the same mound carrying clipped plant matter. The hive stays fixed while its foraging reach changes.")


func _update_disturbance(delta: float) -> void:
	if disturbance_state == "quiet" or disturbance_state == "passed":
		return
	if disturbance_state == "warning":
		disturbance_timer -= delta
		if disturbance_timer <= 9.0 and not refuge_revealed:
			_reveal_presence_nudge()
		if disturbance_timer <= 0.0:
			disturbance_state = "active"
			disturbance_event_id = evidence.record_event(ecology.tick, "environment.disturbance_started", "heat_dust_front:1", [disturbance_event_id])
			disturbance_timer = 0.0
			disturbance_column = 0
			dust_front.visible = true
			_add_discovery("Heat-and-dust front — dries cells and carries toxicity eastward")
			_presence_warn_about(dust_front.position)
			_set_status("The front enters the basin. The flame cuts across its path, recoils, and sounds three descending amber pulses.")
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
		evidence.record_event(ecology.tick, "environment.disturbance_passed", "heat_dust_front:1", [disturbance_event_id], ecology.summary())
		evidence.checkpoint(ecology.tick, "episode_boundary", _evidence_snapshot())
		_set_status("The front passes. Some bare cells are hot and toxic; connected moss and fungus begin recovering from retained moisture and nutrients.")


func _reveal_presence_nudge() -> void:
	refuge_revealed = true
	refuge_marker.visible = true
	ecology.reveal_subsurface_refuge(Vector2(refuge_position.x, refuge_position.z))
	presence_root.visible = true
	_presence_focus("refuge", refuge_position)
	_set_status("As the wind rises, the flame travels to a bare depression and repeats its familiar single focus pulse. It offers no action.")


func _refresh_ecology_visuals() -> void:
	for y in range(EcologyGridModel.HEIGHT):
		for x in range(EcologyGridModel.WIDTH):
			var index: int = y * EcologyGridModel.WIDTH + x
			var sample: Dictionary = ecology.cell_snapshot(x, y)
			var color := Color("46433d")
			color = color.lerp(Color("31515a"), clamp(sample["moisture"] * 0.52, 0.0, 0.5))
			color = color.lerp(Color("9a7240"), clamp(sample["toxicity"] * 0.32, 0.0, 0.3))
			color = color.lerp(Color("81553d"), clamp(sample["dead_biomass"] * 1.8, 0.0, 0.72))
			color = color.lerp(Color("9c8a56"), clamp(sample["microbial_crust"] * 0.8, 0.0, 0.48))
			color = color.lerp(Color("4fa45e"), clamp(sample["moss"] * 1.45, 0.0, 0.9))
			color = color.lerp(Color("c064d3"), clamp(sample["fungus"] * 3.2, 0.0, 0.96))
			color = color.lerp(Color("efb34f"), clamp(sample["fruiting"] * 4.0, 0.0, 0.98))
			color = color.lerp(Color("67c88f"), clamp(sample["rhizome"] * 30.0, 0.0, 0.82))
			color = color.lerp(Color("285d4f"), clamp(sample["canopy"] * 80.0, 0.0, 0.72))
			color = color.lerp(Color("327ba5"), clamp(sample["surface_water"] * 1.3, 0.0, 0.8))
			color = color.lerp(Color("28b9b2"), clamp(sample["aquatic_producer"] * 50.0, 0.0, 0.75))
			color = color.lerp(Color("e2cf62"), clamp(sample["ground_bloom"] * 8.0, 0.0, 0.55))
			color = color.lerp(Color("e790c4"), clamp(sample["canopy_bloom"] * 8.0, 0.0, 0.55))
			color = color.lerp(Color("ad7b45"), clamp(sample["dam_material"] * 5.0, 0.0, 0.65))
			if analysis_lens_enabled and scanner_recovered:
				var world: Vector2 = ecology.world_position(x, y)
				var distance: float = world.distance_to(Vector2(astronaut.position.x, astronaut.position.z))
				if distance <= 2.15:
					color = Color("203033").lerp(Color("45b9cf"), clampf(sample["moisture"] * 0.85, 0.0, 0.72))
					color = color.lerp(Color("e29b4f"), clampf(sample["toxicity"] * 0.82, 0.0, 0.7))
				else:
					color = color.darkened(0.38)
			var material := StandardMaterial3D.new()
			material.albedo_color = color
			material.roughness = 0.9
			if sample["fungus"] >= 0.035:
				material.emission_enabled = true
				material.emission = Color("7b2c89") * min(sample["fungus"] * 2.4, 0.85)
				material.emission_energy_multiplier = 1.15
			ecology_cells[index].material_override = material
			ecology_cells[index].scale.y = 1.0 + sample["canopy"] * 80.0
			if sample["canopy"] >= 0.002:
				ecology_cells[index].position.y = 0.16 + sample["canopy"] * 0.3
			elif sample["fruiting"] >= 0.055:
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
		scanner_readout.text = _scanner_measurement_text("refuge", refuge_cell, 0.54, "The Presence indicated this place, not an action.")
		_record_scan("refuge", refuge_cell)
		_show_scan_pulse(refuge_position, refuge_cell["toxicity"])
		_add_discovery("Subsurface refuge — moist, cooler, dormant trace present")
		_set_status("The bare depression hides moisture below the scanner's normal surface range. The Presence waits without instructing.")
		return
	if nearest_patch == "":
		_set_status("The scanner finds no local biological trace. Move closer to an unusual surface.")
		return

	var patch: Dictionary = patches[nearest_patch]
	patch["scanned"] = true
	var patch_position: Vector3 = patch["node"].global_position
	var cell: Dictionary = ecology.sample_world(Vector2(patch_position.x, patch_position.z))
	var interpretation := _scanner_consequence_text(patch)
	if nearest_patch == "hollow":
		_add_discovery("Dormant moss analogue — sheltered trace")
		scanner_title.text = "FIELD SCANNER  /  SHELTERED FILM"
		scanner_readout.text = _scanner_measurement_text("hollow", cell, 0.62, interpretation)
		_set_status("The cracked screen cannot name the organism, but the hollow retains moisture and stays cool.")
	else:
		_add_discovery("Dormant moss analogue — exposed trace")
		scanner_title.text = "FIELD SCANNER  /  SUN-STRUCK FILM"
		var heat_context := "%s; %s" % [interpretation, "panel shade detected" if patch["shade"] else "direct heat detected"]
		scanner_readout.text = _scanner_measurement_text("crust", cell, 0.48 if not patch["shade"] else 0.66, heat_context)
		if patch["state"] == "failed":
			_add_discovery("Amber toxicity — increases with surface heat")
			_set_status("The failed patch is evidence: water vanished as surface heat and the toxicity band rose together.")
		elif patch["shade"]:
			_add_discovery("Shade — lowers heat and slows moisture loss")
			_set_status("The panel changed two readings at once: heat falls and moisture loss slows.")
		else:
			_set_status("This film resembles the sheltered trace, but heat, moisture, and toxicity differ sharply.")
	_record_scan(nearest_patch, cell)
	_show_scan_pulse(patch_position, cell["toxicity"])


func _water_nearby_patch() -> void:
	if not cache_opened:
		_set_status("No usable water is on hand. The blinking emergency cache may still be intact.")
		return
	if near_refuge:
		if refuge_watered:
			_set_status("The depression already holds the last intervention. Observe its response before committing water elsewhere.")
			return
		if water_doses <= 0:
			_set_status("No water remains to test the Presence's indicated refuge.")
			return
		var command_id := _record_command("water", "refuge", {"doses": 1})
		water_doses -= 1
		refuge_watered = true
		reservoir_established = true
		ecology_started = true
		ecology.add_water(Vector2(refuge_position.x, refuge_position.z), 0.72, 4.0)
		var refuge_cell: Vector2i = ecology.world_to_cell(Vector2(refuge_position.x, refuge_position.z))
		last_intervention_event_id = evidence.record_event(ecology.tick, "intervention.water_added", "cell:%d,%d" % [refuge_cell.x, refuge_cell.y], [command_id], {"amount": 0.72, "remaining_doses": water_doses})
		evidence.checkpoint(ecology.tick, "player_intervention", _evidence_snapshot())
		if refuge_signal_acknowledged:
			_begin_presence_signal("invitation", refuge_position, astronaut.position)
			_set_status("Water sinks into the depression and collects above the sealed substrate as a provisional reservoir. The flame answers around both participants.")
		else:
			_begin_presence_signal("focus", refuge_position)
			_set_status("Water collects in the terrain-bound depression as a provisional reservoir. The flame repeats its focus pulse at the changing cells.")
		return
	if nearest_patch == "":
		_set_status("Water must be committed at a specific patch, not poured from a distance.")
		return
	if water_doses <= 0:
		_set_status("No water remains. Restart to test another hypothesis.")
		return

	var patch: Dictionary = patches[nearest_patch]
	var patch_position: Vector3 = patch["node"].global_position
	var local_sample: Dictionary = ecology.sample_world(Vector2(patch_position.x, patch_position.z))
	var established: bool = patch["state"] == "wet" or patch["state"] == "awakening" or patch["state"] == "thriving"
	if established and local_sample["moisture"] > REWATER_MOISTURE_THRESHOLD:
		_set_status("This habitat still holds sufficient moisture. Observe its response before spending more water.")
		return

	var command_id := _record_command("water", nearest_patch, {"doses": 1, "recovery": established})
	water_doses -= 1
	ecology_started = true
	if not established:
		patch["state"] = "wet"
		patch["age"] = 0.0
	ecology.add_water(Vector2(patch_position.x, patch_position.z))
	var watered_cell: Vector2i = ecology.world_to_cell(Vector2(patch_position.x, patch_position.z))
	last_intervention_event_id = evidence.record_event(ecology.tick, "intervention.water_added", "cell:%d,%d" % [watered_cell.x, watered_cell.y], [command_id], {"site": nearest_patch, "remaining_doses": water_doses, "recovery": established})
	evidence.checkpoint(ecology.tick, "player_intervention", _evidence_snapshot())
	if established:
		_set_status("Water darkens the storm-dried habitat. Its recovery now depends on the life, shelter, and nutrients that survived.")
	else:
		_set_patch_color(nearest_patch, Color("3e6653"), Color("18372d"))
	if not established and patch["shade"]:
		_set_status("The film darkens with a dry crackle. Water remains pooled between its cells.")
	elif not established:
		_set_status("The film darkens—but water beads, hisses, and starts flashing away in the heat.")


func _interact() -> void:
	if near_cache:
		_open_emergency_cache()
		return
	if nearest_harvest_cell.x >= 0:
		_harvest_fruiting()
		return
	if near_refuge and reservoir_established and water_doses < 3:
		var command_id := _record_command("refill", "reservoir", {"canisters": 1})
		water_doses += 1
		evidence.record_event(ecology.tick, "survival.canister_refilled", "reservoir:refuge", [command_id], {"water": water_doses})
		_set_status("The astronaut refills one empty canister from the terrain-bound reservoir. More water remains here, not in the suit.")
		return
	if cache_opened and _at_wreck() and water_doses == 0 and not reservoir_established and reclaimer_intact:
		_request_reclaimer_dismantle()
		return
	if cache_opened and _at_wreck() and exposure > 0.5:
		_recover_at_wreck(false)
		return
	_interact_with_shade()


func _harvest_fruiting() -> void:
	var world: Vector2 = ecology.world_position(nearest_harvest_cell.x, nearest_harvest_cell.y)
	var harvested: int = ecology.harvest_world(world)
	if harvested <= 0:
		_set_status("The fruiting body is not mature enough to harvest.")
		return
	var command_id := _record_command("harvest", "cell:%d,%d" % [nearest_harvest_cell.x, nearest_harvest_cell.y])
	fresh_food += harvested
	evidence.record_event(ecology.tick, "intervention.fungus_harvested", "cell:%d,%d" % [nearest_harvest_cell.x, nearest_harvest_cell.y], [command_id], {"yield": harvested})
	evidence.checkpoint(ecology.tick, "player_intervention", _evidence_snapshot())
	_refresh_ecology_visuals()
	_set_status("The astronaut harvests one fresh fungal fruit. The cell loses some fungus and nutrients; repeated harvests could break the cycle.")


func _open_emergency_cache() -> void:
	if cache_opened:
		return
	var command_id := _record_command("open", "emergency_cache")
	cache_opened = true
	scanner_recovered = true
	water_doses = 3
	ration_packs = 2
	evidence.record_event(ecology.tick, "survival.supplies_recovered", "emergency_cache", [command_id], {"water": water_doses, "rations": ration_packs, "scanner": true})
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
	if _at_wreck():
		_set_status("The wreck can recover the suit without spending water. Save carried water for field emergencies or ecological intervention.")
		return
	if exposure < 8.0:
		_set_status("Suit reserves are still comfortable. Drinking now would spend ecological possibility for little gain.")
		return
	var command_id := _record_command("drink", "astronaut", {"doses": 1})
	water_doses -= 1
	exposure = max(0.0, exposure - 50.0)
	evidence.record_event(ecology.tick, "survival.water_consumed", "astronaut", [command_id], {"remaining_doses": water_doses, "exposure": exposure})
	_set_status("One shared water dose buys roughly half an excursion of survival margin. The ecosystem now has fewer possible interventions.")


func _eat_food() -> void:
	if hunger < 9.0:
		_set_status("The astronaut is not hungry enough to justify consuming food.")
		return
	if fresh_food > 0:
		var command_id := _record_command("eat", "fresh_food")
		fresh_food -= 1
		hunger = max(0.0, hunger - 34.0)
		evidence.record_event(ecology.tick, "survival.food_consumed", "astronaut", [command_id], {"source": "ecosystem", "hunger": hunger})
		_set_status("The first renewable food replaces a finite ration. Its ecological source must remain healthy to feed the astronaut again.")
		return
	if ration_packs > 0:
		var command_id := _record_command("eat", "ration")
		ration_packs -= 1
		hunger = max(0.0, hunger - 42.0)
		evidence.record_event(ecology.tick, "survival.food_consumed", "astronaut", [command_id], {"source": "wreck", "hunger": hunger})
		_set_status("A finite ration buys time but creates no living replacement.")
		return
	_set_status("No carried food remains. The ecosystem is now the only path to another meal.")


func _interact_with_shade() -> void:
	if carrying_shade:
		var command_id := _record_command("place", "shade_panel", {"site": "crust"})
		carrying_shade = false
		shade_placed = true
		shade_placed_cell = ecology.world_to_cell(Vector2(astronaut.position.x, astronaut.position.z))
		var placed_world: Vector2 = ecology.world_position(shade_placed_cell.x, shade_placed_cell.y)
		shade_panel.global_position = Vector3(placed_world.x, 1.15, placed_world.y)
		shade_panel.rotation = Vector3(0.0, 0.18, -0.04)
		ecology.place_equipment_shade(placed_world)
		patches["crust"]["shade"] = placed_world.distance_to(Vector2(patches["crust"]["node"].position.x, patches["crust"]["node"].position.z)) <= 4.0
		last_intervention_event_id = evidence.record_event(ecology.tick, "intervention.shade_added", "cell:%d,%d" % [shade_placed_cell.x, shade_placed_cell.y], [command_id])
		evidence.checkpoint(ecology.tick, "player_intervention", _evidence_snapshot())
		_refresh_ecology_visuals()
		_set_status("The panel shades the visible footprint. Conditions change immediately, but biological success remains unknown.")
		return

	if not carrying_shade and _flat_distance(astronaut.global_position, shade_panel.global_position) < 1.55:
		if not carried_clump.is_empty():
			_set_status("The living clump already occupies the astronaut's bulky carry frame. Place it before lifting the panel.")
			return
		if shade_placed:
			ecology.remove_equipment_shade()
			patches["crust"]["shade"] = false
			shade_placed = false
			shade_placed_cell = Vector2i(-1, -1)
			_refresh_ecology_visuals()
		_record_command("pickup", "shade_panel")
		carrying_shade = true
		_set_status("The astronaut lifts the panel. Its previous footprint loses protection immediately.")
		return

	if carrying_shade:
		_set_status("The panel needs a deliberate site. The sun-struck film is the clearest candidate.")
	else:
		_set_status("There is nothing here to handle.")


func _transplant_living_clump() -> void:
	if not scanner_recovered:
		_set_status("The excavation wrap and sampling blade remain sealed in the emergency cache.")
		return
	if carrying_shade:
		_set_status("The shade panel occupies the astronaut's bulky carry frame. Place it before lifting living material.")
		return
	var cell: Vector2i = ecology.world_to_cell(Vector2(astronaut.position.x, astronaut.position.z))
	if not carried_clump.is_empty():
		_place_carried_clump(cell, false)
		return
	var extracted: Dictionary = ecology.extract_living_clump(cell)
	if extracted.is_empty():
		_set_status("There is no robust living clump here to lift without destroying the patch.")
		return
	carried_clump = extracted
	var command_id := _record_command("extract", "cell:%d,%d" % [cell.x, cell.y], {"resource": extracted["resource"], "amount": extracted["amount"]})
	last_intervention_event_id = evidence.record_event(ecology.tick, "intervention.living_clump_extracted", "cell:%d,%d" % [cell.x, cell.y], [command_id], {"resource": extracted["resource"], "amount": extracted["amount"]})
	evidence.checkpoint(ecology.tick, "player_intervention", _evidence_snapshot())
	_refresh_ecology_visuals()
	_set_status("The astronaut cuts beneath a %s clump. The donor patch is visibly thinner; the living material now occupies the bulky carry frame." % String(extracted["resource"]))


func _place_carried_clump(cell: Vector2i, forced_drop: bool) -> void:
	var resource := String(carried_clump["resource"])
	var amount := float(carried_clump["amount"])
	var source_cell: Vector2i = carried_clump["source_cell"]
	if cell == source_cell and not forced_drop:
		_set_status("This is the disturbed donor cell. Carry the clump elsewhere before setting it down.")
		return
	if ecology.resource_amount(cell, resource) >= 0.72:
		_set_status("This cell is already too densely occupied to receive the clump intact.")
		return
	var sample: Dictionary = ecology.cell_snapshot(cell.x, cell.y)
	var accepted: float = ecology.place_living_clump(cell, resource, amount)
	if accepted <= 0.0:
		_set_status("The clump cannot be seated in this cell.")
		return
	carried_clump = {}
	ecology_started = true
	var command_id := _record_command("drop" if forced_drop else "transplant", "cell:%d,%d" % [cell.x, cell.y], {"resource": resource, "amount": accepted, "source_cell": source_cell})
	last_intervention_event_id = evidence.record_event(ecology.tick, "intervention.living_clump_dropped" if forced_drop else "intervention.living_clump_transplanted", "cell:%d,%d" % [cell.x, cell.y], [command_id], {"resource": resource, "amount": accepted, "source_cell": source_cell, "moisture": sample["moisture"], "temperature": sample["temperature"], "toxicity": sample["toxicity"]})
	evidence.checkpoint(ecology.tick, "player_intervention", _evidence_snapshot())
	_refresh_ecology_visuals()
	if forced_drop:
		return
	if sample["toxicity"] >= 0.5 or sample["temperature"] >= 0.62:
		_set_status("The %s clump is seated, but its edges curl against the hot, toxic ground. Survival will require observation." % resource)
	elif sample["moisture"] < 0.13:
		_set_status("The %s clump is seated intact, but the exposed edges are already drying. Its fate is not yet settled." % resource)
	else:
		_set_status("The %s clump is seated intact. The source has paid the cost; only later growth or decay will show whether this site works." % resource)


func _request_reclaimer_dismantle() -> void:
	if reclaimer_hold_active:
		return
	reclaimer_hold_active = true
	reclaimer_hold_timer = 0.0
	_set_status("Hold E to dismantle the life-support reclaimer: gain one water dose, but all future voluntary recovery advances the longer interval.")


func _update_reclaimer_hold(delta: float) -> void:
	if not reclaimer_hold_active:
		return
	if not Input.is_key_pressed(KEY_E) or not _at_wreck():
		reclaimer_hold_active = false
		reclaimer_hold_timer = 0.0
		return
	reclaimer_hold_timer += delta
	if reclaimer_hold_timer < LAST_WATER_HOLD_SECONDS:
		return
	reclaimer_hold_active = false
	reclaimer_hold_timer = 0.0
	_dismantle_reclaimer()


func _dismantle_reclaimer() -> void:
	var command_id := _record_command("dismantle", "wreck_life_support_reclaimer")
	reclaimer_intact = false
	water_doses = 1
	evidence.record_event(ecology.tick, "survival.reclaimer_dismantled", "wreck_life_support_reclaimer", [command_id], {"water": 1, "voluntary_recovery_seconds": FORCED_RECOVERY_SECONDS})
	_set_status("One sealed reserve becomes usable water. The wreck remains safe, but rapid suit servicing is permanently gone.")


func _update_interface() -> void:
	var current_zone := _current_zone()
	visited_zones[current_zone] = true
	zone_label.text = "ZONE  %s  /  %d of 5 surveyed" % [current_zone, visited_zones.size()]
	if cache_opened:
		var bulky := "     BULKY  %s CLUMP" % String(carried_clump["resource"]).to_upper() if not carried_clump.is_empty() else ("     BULKY  SHADE PANEL" if carrying_shade else "")
		water_label.text = "WATER %d     RATIONS %d     FRESH FOOD %d%s" % [water_doses, ration_packs, fresh_food, bulky]
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
	hunger_label.text = "HUNGER  /  %s" % hunger_state.to_upper()
	var field_seconds := int(field_time * FIELD_TIME_SCALE)
	time_label.text = "FIELD TIME  %02d:%02d  /  ecological response accelerated" % [field_seconds / 60, field_seconds % 60]
	if field_review_open:
		ecosystem_label.text = "FIELD REVIEW  /  survival and ecological time paused  /  J closes"
	elif analysis_lens_enabled:
		ecosystem_label.text = "LOCAL LENS  cyan moisture / amber toxicity / nearby cells only"
	else:
		ecosystem_label.text = "LOCAL LENS OFF  /  V toggles scanner-assisted nearby conditions"
	match disturbance_state:
		"quiet":
			weather_label.text = "WEATHER  %s  / humidity %d%% / cloud %d%%" % [String(weather_simulation.state).replace("_", " ").to_upper(), roundi(weather_simulation.humidity * 100.0), roundi(weather_simulation.cloud_water * 100.0)]
		"warning":
			weather_label.text = "WEATHER  heat-and-dust front approaching in %02ds" % ceili(disturbance_timer)
		"active":
			weather_label.text = "WEATHER  HEAT-AND-DUST FRONT crossing basin"
		_:
			weather_label.text = "WEATHER  %s  / front passed / recovery in progress" % String(weather_simulation.state).replace("_", " ").to_upper()


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


func _scanner_measurement_text(site_id: String, sample: Dictionary, confidence: float, interpretation: String) -> String:
	var moisture_percent := roundi(sample["moisture"] * 100.0)
	var moisture_floor := maxi(0, int(round(float(moisture_percent) / 10.0) * 10.0) - 5)
	var moisture_ceiling := mini(100, moisture_floor + 10)
	var surface_celsius := roundi(-8.0 + sample["temperature"] * 66.0)
	var toxicity_percent := roundi(sample["toxicity"] * 100.0)
	var life_signal := _life_signal_text(sample)
	var lines: Array[String] = [
		"COARSE LOCAL SAMPLE  /  confidence %d%%" % roundi(confidence * 100.0),
		"MOISTURE   %s  /  %02d–%02d%%" % [_moisture_band(sample["moisture"]), moisture_floor, moisture_ceiling],
		"SURFACE    %s  /  ~%d C" % [_temperature_band(sample["temperature"]), surface_celsius],
		"TOXICITY   %s  /  ~%02d%%" % [_toxicity_band(sample["toxicity"]), toxicity_percent],
		"BIOLOGY    " + life_signal,
		"ROOTED     %s  /  canopy %s" % [_signal_band(sample.get("rhizome", 0.0)), _signal_band(sample.get("canopy", 0.0))],
		"AQUATIC    water %s  /  producer %s  /  consumer %s" % [_signal_band(sample.get("surface_water", 0.0)), _signal_band(sample.get("aquatic_producer", 0.0)), _signal_band(sample.get("aquatic_consumer", 0.0))],
		"AIR LINK   sulfur precursor %s  /  volatile %s" % [_signal_band(sample.get("sulfur_precursor", 0.0)), _signal_band(sample.get("volatile_sulfur", 0.0))],
		"FLOWERING  ground %s  /  canopy %s" % [_signal_band(sample.get("ground_bloom", 0.0)), _signal_band(sample.get("canopy_bloom", 0.0))],
		"ANIMAL LINK  pollen %s  /  fungal spores %s  /  dam %s" % [_signal_band(sample.get("pollination", 0.0)), _signal_band(sample.get("fungal_spores", 0.0)), _signal_band(sample.get("dam_material", 0.0))],
		"",
		_change_text(site_id, sample),
		_comparison_text(site_id, sample),
		"",
		interpretation,
		"Readings are coarse, not fabricated."
	]
	return "\n".join(lines)


func _record_scan(site_id: String, sample: Dictionary) -> void:
	scanner_samples[site_id] = sample.duplicate()
	last_scanned_site = site_id


func _change_text(site_id: String, sample: Dictionary) -> String:
	if not scanner_samples.has(site_id):
		return "CHANGE     baseline stored; rescan after intervention"
	var previous: Dictionary = scanner_samples[site_id]
	return "CHANGE     moisture %s / heat %s / toxicity %s" % [
		_delta_word(sample["moisture"] - previous["moisture"]),
		_delta_word(sample["temperature"] - previous["temperature"]),
		_delta_word(sample["toxicity"] - previous["toxicity"])
	]


func _comparison_text(site_id: String, sample: Dictionary) -> String:
	if last_scanned_site == "" or last_scanned_site == site_id or not scanner_samples.has(last_scanned_site):
		return "COMPARE    scan another site to expose differences"
	var other: Dictionary = scanner_samples[last_scanned_site]
	return "COMPARE    %s: %s / %s / %s" % [
		last_scanned_site.replace("_", " ").to_upper(),
		"wetter" if sample["moisture"] > other["moisture"] + 0.035 else ("drier" if sample["moisture"] < other["moisture"] - 0.035 else "similar moisture"),
		"hotter" if sample["temperature"] > other["temperature"] + 0.035 else ("cooler" if sample["temperature"] < other["temperature"] - 0.035 else "similar heat"),
		"more toxic" if sample["toxicity"] > other["toxicity"] + 0.035 else ("less toxic" if sample["toxicity"] < other["toxicity"] - 0.035 else "similar toxicity")
	]


func _delta_word(delta: float) -> String:
	if delta > 0.035: return "rose"
	if delta < -0.035: return "fell"
	return "steady"


func _moisture_band(value: float) -> String:
	if value < 0.1: return "DRY"
	if value < 0.3: return "DAMP"
	if value < 0.62: return "WET"
	return "SATURATED"


func _temperature_band(value: float) -> String:
	if value < 0.28: return "COLD"
	if value < 0.52: return "COOL"
	if value < 0.72: return "WARM"
	return "HOT"


func _toxicity_band(value: float) -> String:
	if value < 0.16: return "LOW"
	if value < 0.38: return "ELEVATED"
	if value < 0.66: return "HIGH"
	return "SEVERE"


func _life_signal_text(sample: Dictionary) -> String:
	if sample.get("canopy", 0.0) >= 0.002: return "canopy metabolism and transpiration detected"
	if sample.get("rhizome", 0.0) >= 0.008: return "rooted mat growth detected"
	if sample.get("aquatic_consumer", 0.0) >= 0.012: return "regulated aquatic food web detected"
	if sample.get("aquatic_producer", 0.0) >= 0.004: return "aquatic producer bloom detected"
	if sample["fruiting"] >= 0.055: return "fruiting tissue detected"
	if sample["fungus"] >= 0.012: return "fungal metabolism detected"
	if sample["moss"] >= 0.03: return "active moss analogue"
	if sample["dormant_moss"] >= 0.08: return "dormant biological trace"
	return "no resolved biological signal"


func _signal_band(value: float) -> String:
	if value < 0.01: return "NONE"
	if value < 0.06: return "TRACE"
	if value < 0.22: return "ACTIVE"
	return "DENSE"


func _toggle_analysis_lens() -> void:
	if not scanner_recovered:
		_set_status("The local analysis lens is part of the damaged scanner still sealed in the emergency cache.")
		return
	analysis_lens_enabled = not analysis_lens_enabled
	lens_anchor_cell = Vector2i(-1, -1)
	_refresh_ecology_visuals()
	_set_status("Local lens enabled. It only emphasizes nearby moisture and toxicity." if analysis_lens_enabled else "Local lens disabled. World cues remain visible without instrument emphasis.")


func _show_scan_pulse(position: Vector3, local_toxicity: float) -> void:
	scan_pulse.position = Vector3(position.x, 0.12, position.z)
	scan_pulse.scale = Vector3.ONE
	scan_pulse.material_override = _material(Color("53c4d5").lerp(Color("e59a4c"), clampf(local_toxicity, 0.0, 1.0)), 0.45)
	scan_pulse.visible = true
	scan_pulse_timer = 1.15


func _update_scan_pulse(delta: float) -> void:
	if scan_pulse_timer <= 0.0:
		if scan_pulse != null:
			scan_pulse.visible = false
		return
	scan_pulse_timer -= delta
	var progress := 1.0 - scan_pulse_timer / 1.15
	scan_pulse.scale = Vector3.ONE * lerpf(0.35, 1.85, progress)


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


func _signal_to_presence() -> void:
	if not presence_root.visible:
		_show_astronaut_signal(astronaut.position, {})
		_set_status("The astronaut sends a short suit-light pulse into the basin. Nothing visibly answers.")
		return

	var target := _nearby_signal_target()
	_show_astronaut_signal(astronaut.position, target)
	if target.is_empty():
		_begin_presence_signal("refusal", presence_root.position)
		_set_status("The astronaut calls without sharing a subject. The flame closes to one flat pulse and remains distant.")
		return

	var target_id: String = target["id"]
	var target_position: Vector3 = target["position"]
	if target_id == presence_focus_id:
		_begin_presence_signal("echo", target_position)
		last_astronaut_signal_id = target_id
		last_astronaut_signal_position = target_position
		last_astronaut_signal_timer = 7.0
		if target_id == "refuge":
			refuge_signal_acknowledged = true
		_set_status("The astronaut points to the same place. The flame answers at the suit light's tempo, then returns its attention there.")
		return

	if last_astronaut_signal_timer > 0.0 and last_astronaut_signal_id != "" and last_astronaut_signal_id != target_id:
		_begin_presence_signal("question", last_astronaut_signal_position, target_position)
		presence_target = (last_astronaut_signal_position + target_position) * 0.5 + Vector3(0.0, 1.15, 0.0)
		presence_focus_id = ""
		last_astronaut_signal_id = target_id
		last_astronaut_signal_position = target_position
		last_astronaut_signal_timer = 7.0
		_set_status("The flame retraces the astronaut's two subjects. Its paired tone rises without resolving, then it waits between them.")
		return

	last_astronaut_signal_id = target_id
	last_astronaut_signal_position = target_position
	last_astronaut_signal_timer = 7.0
	if target_id == "crust" and (patches["crust"]["state"] == "failed" or disturbance_state == "active"):
		_presence_warn_about(target_position)
		_set_status("The flame cuts across the astronaut's line, recoils from the damaged film, and repeats three tight amber pulses.")
	else:
		presence_focus_id = target_id
		presence_target = target_position + Vector3(0.0, 1.15, 0.0)
		_begin_presence_signal("focus", target_position)
		_set_status("The astronaut points. The flame approaches the subject and answers with one narrow pulse, without acting on it.")


func _nearby_signal_target() -> Dictionary:
	if near_refuge:
		return {"id": "refuge", "position": refuge_position}
	if nearest_patch != "":
		return {"id": nearest_patch, "position": patches[nearest_patch]["node"].global_position}
	if grazer_awake and _flat_distance(astronaut.position, grazer_root.position) < 1.8:
		return {"id": "grazer", "position": grazer_root.position}
	return {}


func _show_astronaut_signal(origin: Vector3, target: Dictionary) -> void:
	astronaut_signal_timer = 0.72
	astronaut_signal_ring.position = Vector3(origin.x, 0.12, origin.z)
	astronaut_signal_ring.scale = Vector3.ONE * 0.3
	astronaut_signal_ring.visible = true
	if target.is_empty():
		astronaut_signal_beam.visible = false
		return
	var beam_start := origin + Vector3(0.0, 0.9, 0.0)
	var beam_end: Vector3 = target["position"] + Vector3(0.0, 0.9, 0.0)
	var distance := beam_start.distance_to(beam_end)
	astronaut_signal_beam.position = (beam_start + beam_end) * 0.5
	astronaut_signal_beam.scale = Vector3(1.0, 1.0, distance)
	astronaut_signal_beam.look_at(beam_end, Vector3.UP)
	astronaut_signal_beam.visible = true


func _presence_focus(target_id: String, target_position: Vector3) -> void:
	presence_focus_id = target_id
	presence_target = target_position + Vector3(0.0, 1.15, 0.0)
	_begin_presence_signal("focus", target_position)


func _presence_warn_about(target_position: Vector3) -> void:
	var away := astronaut.position - target_position
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(-1.0, 0.0, 0.0)
	presence_target = target_position + away.normalized() * 1.15 + Vector3(0.0, 1.1, 0.0)
	presence_focus_id = ""
	_begin_presence_signal("warning", target_position)


func _begin_presence_signal(mode: String, primary: Vector3, secondary := Vector3.ZERO) -> void:
	var color := Color("65d9cd")
	var pulses := 1
	presence_signal_interval = 0.62
	var tones := PackedFloat32Array([220.0])
	match mode:
		"echo":
			color = Color("9fe6dc")
			pulses = 2
			presence_signal_interval = 0.34
			tones = PackedFloat32Array([285.0, 285.0])
		"question":
			color = Color("bb91dc")
			pulses = 2
			presence_signal_interval = 0.48
			tones = PackedFloat32Array([220.0, 330.0])
		"warning":
			color = Color("eda24f")
			pulses = 3
			presence_signal_interval = 0.23
			tones = PackedFloat32Array([190.0, 145.0, 105.0])
		"invitation":
			color = Color("79d7b2")
			pulses = 2
			presence_signal_interval = 0.56
			tones = PackedFloat32Array([260.0, 390.0])
		"refusal":
			color = Color("9aa39e")
			pulses = 1
			presence_signal_interval = 0.78
			tones = PackedFloat32Array([125.0])
	presence_signal_primary = Vector3(primary.x, 0.1, primary.z)
	presence_signal_secondary = Vector3(secondary.x, 0.1, secondary.z)
	presence_signal_has_secondary = mode == "question" or mode == "invitation"
	presence_signal_elapsed = 0.0
	presence_signal_duration = presence_signal_interval * float(pulses)
	presence_signal_ring.position = presence_signal_primary
	presence_signal_ring.scale = Vector3.ONE * 0.3
	presence_signal_ring.material_override = _signal_material(color, 0.52)
	presence_signal_ring.visible = true
	_play_presence_tones(tones)


func _play_presence_tones(frequencies: PackedFloat32Array) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mix_rate := 22050
	var tone_seconds := 0.12
	var gap_seconds := 0.055
	var segment_seconds := tone_seconds + gap_seconds
	var total_samples := int(float(mix_rate) * segment_seconds * float(frequencies.size()))
	var data := PackedByteArray()
	data.resize(total_samples * 2)
	for sample_index in range(total_samples):
		var time := float(sample_index) / float(mix_rate)
		var tone_index := mini(int(time / segment_seconds), frequencies.size() - 1)
		var local_time := fmod(time, segment_seconds)
		var value := 0.0
		if local_time < tone_seconds:
			var envelope := sin(PI * local_time / tone_seconds)
			value = sin(TAU * frequencies[tone_index] * local_time) * envelope * 0.22
		data.encode_s16(sample_index * 2, int(value * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	presence_signal_audio.stream = stream
	presence_signal_audio.play()


func _update_presence_signals(delta: float) -> void:
	last_astronaut_signal_timer = maxf(0.0, last_astronaut_signal_timer - delta)
	if astronaut_signal_timer > 0.0:
		astronaut_signal_timer -= delta
		var astronaut_progress := 1.0 - maxf(0.0, astronaut_signal_timer) / 0.72
		astronaut_signal_ring.scale = Vector3.ONE * lerpf(0.3, 1.45, astronaut_progress)
		if astronaut_signal_timer <= 0.0:
			astronaut_signal_ring.visible = false
			astronaut_signal_beam.visible = false
	if presence_signal_elapsed >= presence_signal_duration:
		presence_signal_ring.visible = false
		return
	presence_signal_elapsed += delta
	var pulse_index := int(presence_signal_elapsed / presence_signal_interval)
	var pulse_progress := fmod(presence_signal_elapsed, presence_signal_interval) / presence_signal_interval
	if presence_signal_has_secondary and pulse_index % 2 == 1:
		presence_signal_ring.position = presence_signal_secondary
	else:
		presence_signal_ring.position = presence_signal_primary
	presence_signal_ring.scale = Vector3.ONE * lerpf(0.3, 1.85, pulse_progress)


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
