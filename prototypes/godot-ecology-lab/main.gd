extends Node2D

const Lab = preload("res://ecology_lab.gd")
const GRID_ORIGIN := Vector2(28, 94)
const CELL := 31.0
const PANEL_X := 742.0

var lab
var paused := true
var speed := 1
var accumulator := 0.0
var selected_tool := "water"
var overlay := "combined"
var hovered_cell := Vector2i(-1, -1)
var moss_history: Array[float] = []
var fungus_history: Array[float] = []
var mineral_share_history: Array[float] = []
var detritus_share_history: Array[float] = []
var last_history_tick := -1
var flow_window: Array[Dictionary] = []
var rolling_flows := {"growth": 0.0, "turnover": 0.0, "decomposition": 0.0, "grazed": 0.0, "manure": 0.0}
var scenario := "TEMPORARY OASIS"
var status := "Paused at the dormant start. Add water, then run."


func _ready() -> void:
	lab = Lab.new()
	_record_history()
	queue_redraw()


func _process(delta: float) -> void:
	if not paused:
		accumulator += delta * float(speed)
		while accumulator >= 0.10:
			lab.step()
			_record_flows()
			accumulator -= 0.10
			if lab.tick % 10 == 0:
				_record_history()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered_cell = _screen_to_cell(event.position)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _handle_button_click(event.position):
			return
		var cell := _screen_to_cell(event.position)
		if _valid_cell(cell):
			if selected_tool == "water":
				lab.add_water(cell)
				status = "Water added. Conditions changed; nutrient stock did not."
			else:
				lab.apply_drought(cell)
				status = "Dry pulse applied independently of the grazer."
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				paused = not paused
			KEY_1:
				selected_tool = "water"
			KEY_2:
				selected_tool = "drought"
			KEY_R:
				_reset("oasis")
			KEY_E:
				_reset("seep")
			KEY_C:
				_reset("retention")
			KEY_O:
				_cycle_overlay()
			KEY_3:
				overlay = "combined"
			KEY_4:
				overlay = "water"
			KEY_5:
				overlay = "minerals"
			KEY_6:
				overlay = "detritus"
			KEY_EQUAL, KEY_PLUS:
				speed = min(16, speed * 4)
			KEY_MINUS:
				speed = max(1, speed / 4)


func _draw() -> void:
	_draw_header()
	_draw_grid()
	_draw_grazer()
	_draw_panel()
	_draw_buttons()


func _draw_header() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(28, 35), "FIRST RAIN — ECOLOGY RULES LAB", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("d9e6df"))
	var question := "Can moss hold a finite watering longer than bare ground?" if scenario == "RETENTION TEST" else "Can a small nutrient cycle persist, move, and recover without scripted progression?"
	draw_string(ThemeDB.fallback_font, Vector2(28, 63), question, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("91aaa0"))


func _draw_grid() -> void:
	for y in range(Lab.HEIGHT):
		for x in range(Lab.WIDTH):
			var i: int = lab.index(x, y)
			var rect := Rect2(GRID_ORIGIN + Vector2(x, y) * CELL, Vector2(CELL - 2, CELL - 2))
			var base := Color("403a32")
			match overlay:
				"water": base = Color("27343a").lerp(Color("4eb8d0"), clampf(lab.moisture[i], 0.0, 1.0))
				"minerals": base = Color("302c29").lerp(Color("e0ae58"), clampf(lab.minerals[i] * 2.2, 0.0, 1.0))
				"detritus": base = Color("302c29").lerp(Color("bb713e"), clampf(lab.detritus[i] * 3.0, 0.0, 1.0))
				_:
					base = Color("473d32").lerp(Color("344b50"), clampf(lab.moisture[i] * 0.75, 0.0, 0.7))
			draw_rect(rect, base)
			if overlay == "combined":
				var center := rect.get_center()
				var moss_radius := clampf(sqrt(lab.moss[i]) * 18.0, 0.0, 13.0)
				if moss_radius > 1.0:
					draw_circle(center, moss_radius, Color("55bd62"))
				var fungus_radius := clampf(sqrt(lab.fungus[i]) * 14.0, 0.0, 9.0)
				if fungus_radius > 0.8:
					draw_circle(center + Vector2(5, 4), fungus_radius, Color("b17ad2"))
				if lab.detritus[i] > 0.025:
					draw_circle(center + Vector2(-7, 6), clampf(lab.detritus[i] * 18.0, 1.2, 4.5), Color("d58a4b"))
			var trace: float = lab.manure_trace[i]
			if trace > 0.01:
				var center := rect.get_center()
				var marker_color := Color(0.98, 0.78, 0.24, 0.32 + trace * 0.68)
				draw_arc(center, 8.0 + trace * 4.0, 0.0, TAU, 20, marker_color, 2.2)
				draw_circle(center + Vector2(-3, 1), 2.2, marker_color)
				draw_circle(center + Vector2(3, 3), 1.8, marker_color)
				draw_circle(center + Vector2(1, -3), 1.5, marker_color)
	if _valid_cell(hovered_cell):
		var hover_rect := Rect2(GRID_ORIGIN + Vector2(hovered_cell) * CELL, Vector2(CELL - 2, CELL - 2))
		draw_rect(hover_rect, Color("f3e6b6"), false, 2.0)
	if scenario == "RETENTION TEST":
		_draw_patch_label(Lab.RETENTION_BARE_CENTER, "BARE SOIL")
		_draw_patch_label(Lab.RETENTION_MOSS_CENTER, "LIVING MOSS")


func _draw_grazer() -> void:
	if not lab.grazer_enabled or lab.grazer_state == "dormant":
		return
	var p: Vector2 = GRID_ORIGIN + (lab.grazer_cell + Vector2(0.5, 0.5)) * CELL
	draw_circle(p, 10.0, Color("62e0cb"))
	draw_circle(p + Vector2(7, -2), 5.2, Color("e8a95b"))
	draw_circle(p + Vector2(9, -4), 1.4, Color("1e2928"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-22, -15), "grazer", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


func _draw_panel() -> void:
	draw_rect(Rect2(PANEL_X, 18, 516, 684), Color("10181a"), true)
	draw_line(Vector2(PANEL_X, 18), Vector2(PANEL_X, 702), Color("34474a"), 2.0)
	var totals: Dictionary = lab.totals()
	var tracked: float = lab.total_tracked_nutrients()
	var drift: float = tracked - lab.initial_nutrients
	var y := 52.0
	_text("LIVE STATE", Vector2(PANEL_X + 24, y), 18, Color("d9e6df")); y += 30
	_text("%s   %s   %dx" % [_world_time_label(), "PAUSED" if paused else "RUNNING", speed], Vector2(PANEL_X + 24, y), 14, Color("91aaa0")); y += 19
	_text("tick %d   %s" % [lab.tick, scenario], Vector2(PANEL_X + 24, y), 12, Color("718b82")); y += 21
	_text("moss %.3f   fungus %.3f" % [totals.moss, totals.fungus], Vector2(PANEL_X + 24, y)); y += 19
	_text("minerals %.3f   detritus %.3f" % [totals.minerals, totals.detritus], Vector2(PANEL_X + 24, y)); y += 19
	_text("gut %.3f   manure %d× / %.2f moved" % [lab.grazer_gut, lab.manure_deposit_count, lab.total_manure_deposited], Vector2(PANEL_X + 24, y)); y += 21
	_text("tracked %.4f   unexplained drift %+0.6f" % [tracked, drift], Vector2(PANEL_X + 24, y), 14, Color("70d69a") if absf(drift) < 0.001 else Color("ff6f65")); y += 28
	_text("TRANSFERS — LAST %d TICKS" % flow_window.size(), Vector2(PANEL_X + 24, y), 15, Color("d9e6df")); y += 21
	_text("minerals → moss %.3f    life → detritus %.3f" % [rolling_flows.growth, rolling_flows.turnover], Vector2(PANEL_X + 24, y), 13); y += 18
	_text("detritus → fungus/soil %.3f" % rolling_flows.decomposition, Vector2(PANEL_X + 24, y), 13); y += 18
	_text("moss → grazer %.3f    gut → manure %.3f" % [rolling_flows.grazed, rolling_flows.manure], Vector2(PANEL_X + 24, y), 13); y += 25
	_text("GRAZER", Vector2(PANEL_X + 24, y), 15, Color("d9e6df")); y += 20
	_text("%s — hunger %d%%" % [lab.grazer_state, roundi(lab.grazer_hunger * 100.0)], Vector2(PANEL_X + 24, y), 14, Color("62e0cb")); y += 19
	if lab.last_manure_tick >= 0:
		_text("last manure: %d ticks ago at %d,%d" % [lab.tick - lab.last_manure_tick, lab.last_manure_cell.x, lab.last_manure_cell.y], Vector2(PANEL_X + 24, y), 13, Color("e8c35b")); y += 20
	else:
		_text("last manure: none yet", Vector2(PANEL_X + 24, y), 13, Color("91aaa0")); y += 20
	_text("LIVING BIOMASS — moss / fungus", Vector2(PANEL_X + 24, y), 13, Color("91aaa0")); y += 6
	_draw_line_chart(Rect2(PANEL_X + 24, y, 466, 54), [moss_history, fungus_history], [Color("55bd62"), Color("b17ad2")], -1.0); y += 69
	_text("NUTRIENT LOCATION — mineral / detritus share", Vector2(PANEL_X + 24, y), 13, Color("91aaa0")); y += 6
	_draw_line_chart(Rect2(PANEL_X + 24, y, 466, 54), [mineral_share_history, detritus_share_history], [Color("e0ae58"), Color("d57945")], 1.0); y += 69
	if _valid_cell(hovered_cell):
		var sample: Dictionary = lab.cell_sample(hovered_cell)
		_text("CELL %d,%d — water %.2f  minerals %.2f  moss %.2f" % [hovered_cell.x, hovered_cell.y, sample.water, sample.minerals, sample.moss], Vector2(PANEL_X + 24, y), 12, Color("d9e6df")); y += 17
		_text("fungus %.2f  detritus %.2f  retention %d%%" % [sample.fungus, sample.detritus, roundi(sample.retention * 100.0)], Vector2(PANEL_X + 24, y), 12, Color("aab9b3")); y += 18
	if scenario == "RETENTION TEST":
		var bare_water: float = lab.average_moisture(Lab.RETENTION_BARE_CENTER)
		var moss_water: float = lab.average_moisture(Lab.RETENTION_MOSS_CENTER)
		_text("EQUAL-WATER PATCHES: bare %.3f   moss %.3f" % [bare_water, moss_water], Vector2(PANEL_X + 24, 628), 13, Color("64cfe1"))
	_text("TARGET: %s" % _target_text(), Vector2(PANEL_X + 24, 650), 13, Color("91aaa0"))
	_text(status, Vector2(PANEL_X + 24, 674), 13, Color("d9c57a"))


func _draw_line_chart(rect: Rect2, series_list: Array, colors: Array, fixed_max: float) -> void:
	draw_rect(rect, Color("192326"), true)
	draw_rect(rect, Color("34474a"), false, 1.0)
	if moss_history.size() < 2:
		return
	var max_value := fixed_max
	if fixed_max <= 0.0:
		max_value = 0.01
		for series in series_list:
			for value in series:
				max_value = maxf(max_value, value)
	for series_index in range(series_list.size()):
		var series: Array = series_list[series_index]
		var color: Color = colors[series_index]
		for i in range(1, series.size()):
			var x1 := rect.position.x + float(i - 1) / 59.0 * rect.size.x
			var x2 := rect.position.x + float(i) / 59.0 * rect.size.x
			var y1: float = rect.end.y - series[i - 1] / max_value * rect.size.y
			var y2: float = rect.end.y - series[i] / max_value * rect.size.y
			draw_line(Vector2(x1, y1), Vector2(x2, y2), color, 2.0)


func _draw_buttons() -> void:
	_button(Rect2(28, 548, 108, 35), "1  WATER", selected_tool == "water")
	_button(Rect2(146, 548, 128, 35), "2  DRY PULSE", selected_tool == "drought")
	_button(Rect2(284, 548, 110, 35), "SPACE  %s" % ("RUN" if paused else "PAUSE"), false)
	_button(Rect2(404, 548, 42, 35), "−", false)
	_button(Rect2(456, 548, 66, 35), "%d×" % speed, false)
	_button(Rect2(532, 548, 42, 35), "+", false)
	_button(Rect2(584, 548, 129, 35), "R  RESET", false)
	_button(Rect2(28, 592, 172, 35), "R  DORMANT OASIS", scenario == "TEMPORARY OASIS")
	_button(Rect2(210, 592, 190, 35), "E  ESTABLISHED SEEP", scenario == "DURABLE SEEP")
	_button(Rect2(410, 592, 303, 35), "C  EQUAL-WATER RETENTION TEST", scenario == "RETENTION TEST")
	_button(Rect2(28, 636, 160, 35), "3  COMBINED", overlay == "combined")
	_button(Rect2(198, 636, 160, 35), "4  WATER", overlay == "water")
	_button(Rect2(368, 636, 160, 35), "5  MINERALS", overlay == "minerals")
	_button(Rect2(538, 636, 175, 35), "6  DETRITUS", overlay == "detritus")
	_text("1 tick = 1 in-world minute. Scenarios start paused at 1×. Click basin to intervene.", Vector2(28, 703), 12, Color("aab9b3"))


func _button(rect: Rect2, label: String, active: bool) -> void:
	draw_rect(rect, Color("365b54") if active else Color("202e30"), true)
	draw_rect(rect, Color("79a89b") if active else Color("405457"), false, 1.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(10, 23), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e2ece7"))


func _handle_button_click(position: Vector2) -> bool:
	if Rect2(28, 548, 108, 35).has_point(position): selected_tool = "water"
	elif Rect2(146, 548, 128, 35).has_point(position): selected_tool = "drought"
	elif Rect2(284, 548, 110, 35).has_point(position): paused = not paused
	elif Rect2(404, 548, 42, 35).has_point(position): speed = max(1, speed / 4)
	elif Rect2(532, 548, 42, 35).has_point(position): speed = min(16, speed * 4)
	elif Rect2(584, 548, 129, 35).has_point(position): _reset("oasis")
	elif Rect2(28, 592, 172, 35).has_point(position): _reset("oasis")
	elif Rect2(210, 592, 190, 35).has_point(position): _reset("seep")
	elif Rect2(410, 592, 303, 35).has_point(position): _reset("retention")
	elif Rect2(28, 636, 160, 35).has_point(position): overlay = "combined"
	elif Rect2(198, 636, 160, 35).has_point(position): overlay = "water"
	elif Rect2(368, 636, 160, 35).has_point(position): overlay = "minerals"
	elif Rect2(538, 636, 175, 35).has_point(position): overlay = "detritus"
	else: return false
	return true


func _cycle_overlay() -> void:
	var overlays := ["combined", "water", "minerals", "detritus"]
	overlay = overlays[(overlays.find(overlay) + 1) % overlays.size()]


func _reset(next_scenario: String) -> void:
	paused = true
	speed = 1
	accumulator = 0.0
	selected_tool = "water"
	overlay = "combined"
	if next_scenario == "seep":
		lab.reset_established()
		scenario = "DURABLE SEEP"
		status = "Durable seep loaded. Run to test persistent cycling."
	elif next_scenario == "retention":
		lab.reset_retention_comparison()
		scenario = "RETENTION TEST"
		overlay = "water"
		status = "Equal water applied. Run and compare bare soil with living moss."
	else:
		lab.reset_dormant()
		scenario = "TEMPORARY OASIS"
		status = "Dormant oasis restored. Add finite water, then run."
	moss_history.clear()
	fungus_history.clear()
	mineral_share_history.clear()
	detritus_share_history.clear()
	flow_window.clear()
	for key in rolling_flows:
		rolling_flows[key] = 0.0
	last_history_tick = -1
	_record_history()


func _world_time_label() -> String:
	var total_minutes: int = lab.tick * Lab.MINUTES_PER_TICK
	var day: int = total_minutes / 1440 + 1
	var minute_of_day: int = total_minutes % 1440
	return "DAY %d  %02d:%02d" % [day, minute_of_day / 60, minute_of_day % 60]


func _target_text() -> String:
	match scenario:
		"TEMPORARY OASIS": return "finite oasis; moss holds water, but rewatering is eventually required"
		"DURABLE SEEP": return "persistent cycle supplied by a subsurface seep"
		_: return "after one day, moss remains wetter than equally watered bare soil"


func _draw_patch_label(cell: Vector2i, label: String) -> void:
	var position := GRID_ORIGIN + Vector2(cell.x - 1.5, cell.y - 3.0) * CELL
	draw_string(ThemeDB.fallback_font, position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f3e6b6"))


func _record_history() -> void:
	if last_history_tick == lab.tick:
		return
	last_history_tick = lab.tick
	var totals: Dictionary = lab.totals()
	var tracked: float = maxf(lab.total_tracked_nutrients(), 0.001)
	moss_history.append(totals.moss)
	fungus_history.append(totals.fungus)
	mineral_share_history.append(totals.minerals / tracked)
	detritus_share_history.append(totals.detritus / tracked)
	if moss_history.size() > 60:
		moss_history.pop_front()
		fungus_history.pop_front()
		mineral_share_history.pop_front()
		detritus_share_history.pop_front()


func _record_flows() -> void:
	var sample: Dictionary = lab.last_flows.duplicate()
	flow_window.append(sample)
	for key in rolling_flows:
		rolling_flows[key] += sample[key]
	if flow_window.size() > 50:
		var expired: Dictionary = flow_window.pop_front()
		for key in rolling_flows:
			rolling_flows[key] -= expired[key]


func _screen_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori((position.x - GRID_ORIGIN.x) / CELL), floori((position.y - GRID_ORIGIN.y) / CELL))


func _valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < Lab.WIDTH and cell.y >= 0 and cell.y < Lab.HEIGHT


func _text(value: String, position: Vector2, size := 14, color := Color("aab9b3")) -> void:
	draw_string(ThemeDB.fallback_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
