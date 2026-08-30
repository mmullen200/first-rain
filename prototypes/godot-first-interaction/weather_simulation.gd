class_name PrototypeWeatherSimulation
extends RefCounted

# THROWAWAY PROTOTYPE. A seeded regional atmosphere whose windows emerge from
# evolving heat, pressure, wind, and humidity. Ecology contributes vapor and
# cloud-active biological material but cannot schedule precipitation.

const SNAPSHOT_VERSION := 1

var seed := 1
var tick := 0
var temperature := 0.62
var humidity := 0.18
var pressure := 0.58
var wind := 0.22
var dust_load := 0.08
var cloud_water := 0.0
var precipitation := 0.0
var state := "clear"
var sustained_rain_ticks := 0
var first_rain_reached := false
var event_history: Array[Dictionary] = []
var _next_event_sequence := 1


func _init(simulation_seed := 1) -> void:
	seed = simulation_seed


func step(ecology_state: Dictionary) -> Array[Dictionary]:
	var event_start := event_history.size()
	tick += 1
	var previous_state := state
	var regional_wave := sin(float(tick + seed * 11) * 0.071) * 0.5 + sin(float(tick * 3 + seed * 5) * 0.019) * 0.5
	var thermal_noise := _noise(tick, 17) - 0.5
	var pressure_noise := _noise(tick, 41) - 0.5
	var biological_vapor: float = clampf(float(ecology_state.get("total_canopy", 0.0)) / 0.8 + float(ecology_state.get("total_surface_water", 0.0)) / 1.2, 0.0, 0.14)
	var cloud_nuclei: float = clampf(float(ecology_state.get("total_volatile_sulfur", 0.0)) / 0.04 + float(ecology_state.get("fungus_cells", 0)) / 30.0, 0.0, 0.5)

	var heat_target := clampf(0.57 + regional_wave * 0.19 + thermal_noise * 0.12, 0.18, 0.92)
	temperature = lerpf(temperature, heat_target, 0.055)
	var previous_pressure := pressure
	pressure = clampf(lerpf(pressure, 0.54 + pressure_noise * 0.38 + regional_wave * 0.08, 0.075), 0.12, 0.9)
	var pressure_change := absf(pressure - previous_pressure)
	wind = clampf(lerpf(wind, 0.16 + pressure_change * 9.0 + absf(regional_wave) * 0.2, 0.12), 0.05, 0.92)
	var evaporation_input := biological_vapor * (0.04 + temperature * 0.04)
	humidity = clampf(humidity + evaporation_input + maxf(0.0, 0.55 - pressure) * 0.004 - temperature * 0.0015 - precipitation * 0.1, 0.03, 1.0)
	var lift := clampf((0.58 - pressure) * 1.8 + wind * 0.38, 0.0, 1.0)
	var condensation := maxf(0.0, humidity - (0.69 - lift * 0.18)) * (0.025 + cloud_nuclei * 0.055)
	cloud_water = clampf(cloud_water + condensation - temperature * 0.0012 - precipitation * 0.15, 0.0, 1.0)
	var rain_readiness := cloud_water * (0.42 + cloud_nuclei) * lift * (1.0 - maxf(0.0, temperature - 0.72))
	precipitation = clampf((rain_readiness - 0.045) * 4.5, 0.0, 0.42)

	var dust_source := maxf(0.0, temperature - 0.58) * maxf(0.0, 0.58 - humidity) * wind * 0.16
	dust_load = clampf(dust_load * (0.975 - precipitation * 0.16) + dust_source, 0.0, 1.0)
	if precipitation >= 0.018:
		state = "rain"
		sustained_rain_ticks += 1
	elif dust_load >= 0.16 and wind >= 0.25:
		state = "dust"
		sustained_rain_ticks = 0
	elif temperature >= 0.64:
		state = "heat"
		sustained_rain_ticks = 0
	elif humidity >= 0.58:
		state = "cloud_building"
		sustained_rain_ticks = 0
	else:
		state = "clear"
		sustained_rain_ticks = 0

	if state != previous_state:
		_emit("weather.%s" % state, {"previous": previous_state, "state": state})
	if not first_rain_reached and sustained_rain_ticks >= 3:
		first_rain_reached = true
		_emit("weather.first_rain", {"precipitation": precipitation, "sustained_ticks": sustained_rain_ticks})
	return event_history.slice(event_start)


func snapshot() -> Dictionary:
	return {
		"version": SNAPSHOT_VERSION, "seed": seed, "tick": tick,
		"temperature": temperature, "humidity": humidity, "pressure": pressure,
		"wind": wind, "dust_load": dust_load, "cloud_water": cloud_water,
		"precipitation": precipitation, "state": state,
		"sustained_rain_ticks": sustained_rain_ticks, "first_rain_reached": first_rain_reached,
		"events": event_history.duplicate(true), "next_event_sequence": _next_event_sequence
	}


func restore(saved: Dictionary) -> bool:
	if int(saved.get("version", 0)) != SNAPSHOT_VERSION:
		return false
	for key in ["seed", "tick", "temperature", "humidity", "pressure", "wind", "dust_load", "cloud_water", "precipitation", "state", "sustained_rain_ticks", "first_rain_reached", "events", "next_event_sequence"]:
		if not saved.has(key):
			return false
	seed = int(saved["seed"])
	tick = int(saved["tick"])
	temperature = float(saved["temperature"])
	humidity = float(saved["humidity"])
	pressure = float(saved["pressure"])
	wind = float(saved["wind"])
	dust_load = float(saved["dust_load"])
	cloud_water = float(saved["cloud_water"])
	precipitation = float(saved["precipitation"])
	state = String(saved["state"])
	sustained_rain_ticks = int(saved["sustained_rain_ticks"])
	first_rain_reached = bool(saved["first_rain_reached"])
	event_history.assign(saved["events"])
	_next_event_sequence = int(saved["next_event_sequence"])
	return true


func _noise(at_tick: int, salt: int) -> float:
	var value := posmod(at_tick * 1103515245 + seed * 12345 + salt * 265443576, 2147483647)
	return float(value) / 2147483647.0


func _emit(taxonomy: String, facts: Dictionary) -> void:
	event_history.append({
		"id": "weather-evt-%04d" % _next_event_sequence,
		"tick": tick,
		"taxonomy": taxonomy,
		"facts": facts.duplicate(true)
	})
	_next_event_sequence += 1
