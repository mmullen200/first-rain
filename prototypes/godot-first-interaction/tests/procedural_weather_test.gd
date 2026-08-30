extends SceneTree

const WeatherSimulation = preload("res://weather_simulation.gd")


func _init() -> void:
	var barren := {"total_canopy": 0.0, "total_surface_water": 0.0, "total_volatile_sulfur": 0.0, "fungus_cells": 0}
	var restored := {"total_canopy": 22.0, "total_surface_water": 28.0, "total_volatile_sulfur": 1.8, "fungus_cells": 55}
	var dry_weather = WeatherSimulation.new(91)
	var dry_rain_ticks := 0
	for _step in range(900):
		dry_weather.step(barren)
		if dry_weather.state == "rain":
			dry_rain_ticks += 1
	_assert(not dry_weather.first_rain_reached, "a barren basin should not manufacture sustained First Rain")

	var weather = WeatherSimulation.new(91)
	var states: Dictionary = {}
	var first_rain_tick := -1
	for _step in range(900):
		weather.step(restored)
		states[weather.state] = true
		if weather.first_rain_reached and first_rain_tick < 0:
			first_rain_tick = weather.tick
	_assert(first_rain_tick > 0, "restored ecology should make First Rain possible inside a natural weather window")
	_assert(states.has("heat") or states.has("dust"), "regional weather should still produce non-rain disturbances")
	_assert(states.has("cloud_building"), "rain should be preceded by a legible atmospheric build")

	var replay = WeatherSimulation.new(91)
	for _step in range(900):
		replay.step(restored)
	_assert(replay.snapshot() == weather.snapshot(), "the recorded seed and ecological inputs should replay exactly")
	_assert(not weather.snapshot().has("presence"), "the Presence must not be part of weather causality")
	print("PASS: seeded procedural weather produces disturbances and ecosystem-enabled First Rain without a fixed schedule or Presence trigger")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("FAIL: " + message)
	quit(1)
