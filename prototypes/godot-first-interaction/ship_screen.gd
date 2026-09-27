extends RefCounted

# THROWAWAY PROTOTYPE.
# The spaceplane's 8-bit ship-status screen. It draws blocky 3x5 pixel text and
# bars into a small image shown with nearest-neighbour filtering, so it reads
# as a low-resolution cockpit display. Presentation only: main.gd hands it the
# readings each refresh.

const WIDTH := 164
const HEIGHT := 102
const COLUMN := 4
const ROW := 6
const MARGIN := 2

const BACKGROUND := Color("08160f")
const TEXT := Color("79f59a")
const DIM := Color("3c7a52")
const AMBER := Color("ffc34d")
const RED := Color("ff5a48")

const GLYPHS := {
	"A": [".#.", "#.#", "###", "#.#", "#.#"], "B": ["##.", "#.#", "##.", "#.#", "##."],
	"C": [".##", "#..", "#..", "#..", ".##"], "D": ["##.", "#.#", "#.#", "#.#", "##."],
	"E": ["###", "#..", "##.", "#..", "###"], "F": ["###", "#..", "##.", "#..", "#.."],
	"G": [".##", "#..", "#.#", "#.#", ".##"], "H": ["#.#", "#.#", "###", "#.#", "#.#"],
	"I": ["###", ".#.", ".#.", ".#.", "###"], "J": ["..#", "..#", "..#", "#.#", ".#."],
	"K": ["#.#", "#.#", "##.", "#.#", "#.#"], "L": ["#..", "#..", "#..", "#..", "###"],
	"M": ["#.#", "###", "###", "#.#", "#.#"], "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
	"O": [".#.", "#.#", "#.#", "#.#", ".#."], "P": ["##.", "#.#", "##.", "#..", "#.."],
	"Q": [".#.", "#.#", "#.#", "##.", ".##"], "R": ["##.", "#.#", "##.", "#.#", "#.#"],
	"S": [".##", "#..", ".#.", "..#", "##."], "T": ["###", ".#.", ".#.", ".#.", ".#."],
	"U": ["#.#", "#.#", "#.#", "#.#", "###"], "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
	"W": ["#.#", "#.#", "###", "###", "#.#"], "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
	"Y": ["#.#", "#.#", ".#.", ".#.", ".#."], "Z": ["###", "..#", ".#.", "#..", "###"],
	"0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
	"2": ["##.", "..#", ".#.", "#..", "###"], "3": ["##.", "..#", ".#.", "..#", "##."],
	"4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "##.", "..#", "##."],
	"6": [".##", "#..", "###", "#.#", "###"], "7": ["###", "..#", ".#.", ".#.", ".#."],
	"8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "##."],
	"%": ["#.#", "..#", ".#.", "#..", "#.#"], "/": ["..#", "..#", ".#.", "#..", "#.."],
	":": ["...", ".#.", "...", ".#.", "..."], "-": ["...", "...", "###", "...", "..."],
	".": ["...", "...", "...", "...", ".#."], ",": ["...", "...", "...", ".#.", "#.."],
	"~": ["...", ".##", "##.", "...", "..."], "+": ["...", ".#.", "###", ".#.", "..."],
	"=": ["...", "###", "...", "###", "..."], ">": ["#..", ".#.", "..#", ".#.", "#.."],
	"<": ["..#", ".#.", "#..", ".#.", "..#"], "!": [".#.", ".#.", ".#.", "...", ".#."],
	"?": ["##.", "..#", ".#.", "...", ".#."], "(": [".#.", "#..", "#..", "#..", ".#."],
	")": [".#.", "..#", "..#", "..#", ".#."],
}

var image: Image
var texture: ImageTexture


func _init() -> void:
	image = Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGB8)
	image.fill(BACKGROUND)
	texture = ImageTexture.create_from_image(image)


# Expected readings: field_time (s), reclaimer_running (bool), next_dose
# (0..1), dose_seconds, water, water_capacity, integrity (0..1),
# wear_per_minute (fraction), shutdown_minutes, exposure (0..100), hunger
# (text), rations, fresh_food, weather (text).
func render(readings: Dictionary) -> void:
	image.fill(BACKGROUND)
	var seconds := int(readings.get("field_time", 0.0))
	_text(0, 0, "SHIP STATUS", TEXT)
	_text(28, 0, "T+%02d:%02d" % [seconds / 60, seconds % 60], DIM)
	_rule(1)

	var running: bool = readings.get("reclaimer_running", false)
	_text(0, 2, "WATER RECLAIMER", TEXT)
	_text(28, 2, "RUNNING" if running else "STANDBY", TEXT if running else AMBER)
	if running:
		_text(1, 3, "NEXT DOSE", DIM)
		var next_dose: float = readings.get("next_dose", 0.0)
		_bar(11, 3, 20, next_dose, TEXT)
		_text(32, 3, "%3d%%" % roundi(next_dose * 100.0), TEXT)
		_text(1, 4, "RATE", DIM)
		_text(11, 4, "1 DOSE / %dS" % roundi(readings.get("dose_seconds", 0.0)), TEXT)
	else:
		_text(1, 3, "OPEN THE EMERGENCY CACHE", AMBER)
		_text(1, 4, "TO RESTART RECLAIMER", AMBER)
	_text(1, 5, "STORE", DIM)
	_text(11, 5, "%d/%d DOSES" % [readings.get("water", 0), readings.get("water_capacity", 0)], TEXT)

	var integrity: float = readings.get("integrity", 1.0)
	var integrity_color := TEXT if integrity > 0.5 else (AMBER if integrity > 0.2 else RED)
	_text(1, 6, "INTEGRITY", DIM)
	_bar(11, 6, 20, integrity, integrity_color)
	_text(32, 6, "%3d%%" % roundi(integrity * 100.0), integrity_color)
	_text(1, 7, "WEAR", DIM)
	_text(11, 7, "%.1f%%/MIN" % (readings.get("wear_per_minute", 0.0) * 100.0), integrity_color)
	var shutdown_minutes: int = roundi(readings.get("shutdown_minutes", 0.0))
	_text(1, 8, "SHUTDOWN", DIM)
	_text(11, 8, "IN ~%d MIN" % shutdown_minutes if shutdown_minutes > 0 else "IMMINENT", integrity_color)
	_rule(9)

	_text(0, 10, "LIFE SUPPORT", TEXT)
	var exposure: float = readings.get("exposure", 0.0)
	var exposure_color := TEXT if exposure < 50.0 else (AMBER if exposure < 80.0 else RED)
	_text(1, 11, "SUIT EXPO", DIM)
	_bar(11, 11, 20, exposure / 100.0, exposure_color)
	_text(32, 11, "%3d%%" % roundi(exposure), exposure_color)
	var hunger := String(readings.get("hunger", "")).to_upper()
	_text(1, 12, "HUNGER", DIM)
	_text(11, 12, hunger, TEXT if hunger == "FED" else AMBER)
	_text(1, 13, "RATIONS", DIM)
	_text(11, 13, "%d   FRESH FOOD %d" % [readings.get("rations", 0), readings.get("fresh_food", 0)], TEXT)
	_text(1, 14, "CABIN", DIM)
	_text(11, 14, "HULL OPEN - SUIT ON", AMBER)
	_text(0, 15, "OUTSIDE", DIM)
	_text(11, 15, String(readings.get("weather", "")).to_upper(), TEXT)
	texture.update(image)


func _text(column: int, row: int, text: String, color: Color) -> void:
	var x := MARGIN + column * COLUMN
	var y := MARGIN + row * ROW
	for character in text:
		var glyph: Array = GLYPHS.get(character, [])
		for line in range(glyph.size()):
			var bits: String = glyph[line]
			for dot in range(3):
				if bits[dot] == "#" and x + dot < WIDTH and y + line < HEIGHT:
					image.set_pixel(x + dot, y + line, color)
		x += COLUMN


func _bar(column: int, row: int, columns: int, fraction: float, color: Color) -> void:
	var x := MARGIN + column * COLUMN
	var y := MARGIN + row * ROW
	var width := columns * COLUMN - 1
	image.fill_rect(Rect2i(x, y, width, 5), DIM.darkened(0.55))
	image.fill_rect(Rect2i(x, y, roundi(width * clampf(fraction, 0.0, 1.0)), 5), color)


func _rule(row: int) -> void:
	var y := MARGIN + row * ROW + 2
	for x in range(MARGIN, WIDTH - MARGIN, 2):
		image.set_pixel(x, y, DIM)
