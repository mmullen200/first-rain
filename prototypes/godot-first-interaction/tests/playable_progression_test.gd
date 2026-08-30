extends SceneTree

const EcologyGrid = preload("res://ecology_grid.gd")
const WeatherSimulation = preload("res://weather_simulation.gd")


func _init() -> void:
	var ecology = EcologyGrid.new()
	var weather = WeatherSimulation.new(1701)
	var hollow := Vector2(-2.7, -1.55)
	var refuge := Vector2(37.0, 23.0)
	ecology.add_water(hollow)
	var milestones := {"rhizome": -1, "canopy": -1, "aquatic": -1, "first_rain": -1}
	for simulation_tick in range(1200):
		if simulation_tick == 180:
			ecology.reveal_subsurface_refuge(refuge)
		if simulation_tick > 0 and simulation_tick % 90 == 0:
			var intervention_site := hollow if simulation_tick % 180 == 0 else refuge
			ecology.add_water(intervention_site, 0.72, 4.0)
		ecology.step()
		weather.step(ecology.summary())
		if weather.precipitation > 0.0:
			ecology.add_water(Vector2(16.0, 10.0), weather.precipitation * 0.04, 58.0)
		var state: Dictionary = ecology.summary()
		if milestones["rhizome"] < 0 and int(state["rhizome_cells"]) >= 1:
			milestones["rhizome"] = simulation_tick
		if milestones["canopy"] < 0 and int(state["canopy_cells"]) >= 1:
			milestones["canopy"] = simulation_tick
		if milestones["aquatic"] < 0 and int(state["aquatic_cells"]) >= 1:
			milestones["aquatic"] = simulation_tick
		if milestones["first_rain"] < 0 and weather.first_rain_reached:
			milestones["first_rain"] = simulation_tick
	_assert(milestones["rhizome"] >= 0, "finite watering plus Reservoir refills never reaches rooted succession")
	_assert(milestones["canopy"] >= 0, "playable interventions never establish canopy")
	_assert(milestones["aquatic"] >= 0, "playable interventions never establish an aquatic producer")
	_assert(milestones["first_rain"] >= 0, "playable succession never reaches natural First Rain")
	print("PASS: playable watering reaches rooted, canopy, aquatic, and First Rain milestones: ", milestones)
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("FAIL: " + message)
	quit(1)
