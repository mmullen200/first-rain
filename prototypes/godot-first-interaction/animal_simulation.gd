class_name PrototypeAnimalSimulation
extends RefCounted

# THROWAWAY PROTOTYPE.
# Authoritative pure-data module for larger organisms. Callers register stable
# agents, submit astronaut interventions, advance deterministic ticks, and
# observe snapshots/events. Species choose intentions internally; presentation
# nodes never decide ecological outcomes.

const SNAPSHOT_VERSION := 1
const DIRECTIONS := [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)
]

var ecology
var seed := 1
var tick := 0
var agents: Dictionary = {}
var event_history: Array[Dictionary] = []
var conservation_violations: Array[String] = []
var _pending_interventions: Array[Dictionary] = []
var _next_event_sequence := 1
var _next_birth_sequence := 1


func _init(ecology_model = null, simulation_seed := 1) -> void:
	ecology = ecology_model
	seed = simulation_seed


func register_agent(species: String, stable_id: String, initial_state := {}) -> bool:
	if ecology == null or stable_id.is_empty() or agents.has(stable_id):
		return false
	if species not in ["grazer", "predator", "colony", "vector", "wetland_engineer"]:
		return false
	var initial_activity: String = String({
		"grazer": "seeking",
		"predator": "hunting",
		"colony": "foraging",
		"vector": "searching",
		"wetland_engineer": "gathering"
	}.get(species, "seeking"))
	var cell: Vector2i = initial_state.get("cell", Vector2i.ZERO)
	var bounded_cell := _bounded_cell(cell)
	var agent := {
		"id": stable_id,
		"species": species,
		"cell": bounded_cell,
		"home_cell": initial_state.get("home_cell", bounded_cell),
		"worker_cell": initial_state.get("worker_cell", bounded_cell),
		"worker_target": initial_state.get("worker_target", bounded_cell),
		"worker_phase": String(initial_state.get("worker_phase", "idle")),
		"worker_load_resource": String(initial_state.get("worker_load_resource", "")),
		"worker_load": float(initial_state.get("worker_load", 0.0)),
		"alive": true,
		"state": initial_activity,
		"hunger": float(initial_state.get("hunger", 1.0)),
		"body_biomass": float(initial_state.get("body_biomass", 1.0)),
		"carried_material": initial_state.get("carried_material", {}).duplicate(true),
		"digestion_ticks": int(initial_state.get("digestion_ticks", 0)),
		"digesting_resource": String(initial_state.get("digesting_resource", "")),
		"last_feeding_cell": initial_state.get("last_feeding_cell", Vector2i(-1, -1)),
		"last_gather_cell": initial_state.get("last_gather_cell", Vector2i(-1, -1)),
		"heading": initial_state.get("heading", Vector2i(1, 0)),
		"heading_steps": int(initial_state.get("heading_steps", 4)),
		"move_cooldown": int(initial_state.get("move_cooldown", 0)),
		"fear": float(initial_state.get("fear", 0.0)),
		"reproductive_readiness": float(initial_state.get("reproductive_readiness", 0.0)),
		"generation": int(initial_state.get("generation", 0)),
		"parents": initial_state.get("parents", []).duplicate(),
		"brood": float(initial_state.get("brood", 0.0)),
		"pollen_load": float(initial_state.get("pollen_load", 0.0)),
		"spore_load": float(initial_state.get("spore_load", 0.0))
	}
	agents[stable_id] = agent
	_emit("organism.registered", stable_id, {"species": species, "cell": agent["cell"]})
	return true


func submit_intervention(intervention: Dictionary) -> bool:
	var kind := String(intervention.get("type", ""))
	var agent_id := String(intervention.get("agent_id", ""))
	if not agents.has(agent_id) or kind not in ["relocate", "deter", "injure"]:
		return false
	var accepted := intervention.duplicate(true)
	accepted["sequence"] = _pending_interventions.size()
	_pending_interventions.append(accepted)
	return true


func step() -> Array[Dictionary]:
	var event_start := event_history.size()
	tick += 1
	ecology.step()
	_resolve_interventions()
	var ids := agents.keys()
	ids.sort()
	var intentions: Array[Dictionary] = []
	for agent_id in ids:
		var agent: Dictionary = agents[agent_id]
		if bool(agent["alive"]):
			intentions.append(_choose_intention(agent))
	for intention in intentions:
		_resolve_intention(intention)
	return event_history.slice(event_start)


func agent_state(stable_id: String) -> Dictionary:
	if not agents.has(stable_id):
		return {}
	return agents[stable_id].duplicate(true)


func cell_state(cell: Vector2i) -> Dictionary:
	return ecology.cell_snapshot(_bounded_cell(cell).x, _bounded_cell(cell).y)


func snapshot() -> Dictionary:
	return {
		"version": SNAPSHOT_VERSION,
		"seed": seed,
		"tick": tick,
		"agents": agents.duplicate(true),
		"pending_interventions": _pending_interventions.duplicate(true),
		"events": event_history.duplicate(true),
		"next_event_sequence": _next_event_sequence,
		"next_birth_sequence": _next_birth_sequence,
		"conservation_violations": conservation_violations.duplicate(),
		"ecology": ecology.full_snapshot()
	}


func restore(snapshot_state: Dictionary) -> bool:
	if int(snapshot_state.get("version", 0)) != SNAPSHOT_VERSION:
		return false
	if not ecology.restore_snapshot(snapshot_state.get("ecology", {})):
		return false
	seed = int(snapshot_state["seed"])
	tick = int(snapshot_state["tick"])
	agents = snapshot_state["agents"].duplicate(true)
	_pending_interventions = snapshot_state["pending_interventions"].duplicate(true)
	event_history.assign(snapshot_state["events"])
	_next_event_sequence = int(snapshot_state["next_event_sequence"])
	_next_birth_sequence = int(snapshot_state.get("next_birth_sequence", 1))
	conservation_violations.assign(snapshot_state["conservation_violations"])
	return true


func _resolve_interventions() -> void:
	_pending_interventions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["sequence"]) < int(b["sequence"]))
	for intervention in _pending_interventions:
		var agent_id := String(intervention["agent_id"])
		if not agents.has(agent_id):
			continue
		var agent: Dictionary = agents[agent_id]
		match String(intervention["type"]):
			"relocate":
				agent["cell"] = _bounded_cell(intervention.get("cell", agent["cell"]))
				if String(agent["species"]) == "colony":
					agent["home_cell"] = agent["cell"]
					agent["worker_cell"] = agent["cell"]
					agent["worker_target"] = agent["cell"]
					agent["worker_phase"] = "idle"
				_emit("intervention.animal_relocated", agent_id, {"cell": agent["cell"]})
			"deter":
				agent["fear"] = clampf(float(agent["fear"]) + float(intervention.get("pressure", 0.5)), 0.0, 1.0)
				_emit("intervention.animal_deterred", agent_id, {"fear": agent["fear"]})
			"injure":
				var requested: float = maxf(0.0, float(intervention.get("amount", 0.0)))
				var removable := minf(float(agent["body_biomass"]), requested)
				var removed := _deposit_to_environment(agent["cell"], "dead_biomass", removable, agent_id)
				agent["body_biomass"] = float(agent["body_biomass"]) - removed
				_emit("intervention.animal_injured", agent_id, {"amount": removed})
				if float(agent["body_biomass"]) <= 0.0001:
					agent["alive"] = false
					agent["state"] = "dead"
					_emit("organism.died", agent_id, {"cause": "injury"})
		agents[agent_id] = agent
	_pending_interventions.clear()


func _choose_intention(agent: Dictionary) -> Dictionary:
	var readiness: float = float(agent["reproductive_readiness"])
	if float(agent["hunger"]) < 0.35 and float(agent["body_biomass"]) > 0.55 and float(agent["fear"]) < 0.3:
		readiness = minf(1.0, readiness + 0.025)
	else:
		readiness = maxf(0.0, readiness - 0.01)
	agent["reproductive_readiness"] = readiness
	agents[agent["id"]] = agent
	if readiness >= 1.0:
		var mate_id := _ready_mate_id(agent)
		if not mate_id.is_empty():
			return {"type": "reproduce", "agent_id": agent["id"], "mate_id": mate_id}
	match String(agent["species"]):
		"grazer":
			return _choose_grazer_intention(agent)
		"predator":
			return _choose_predator_intention(agent)
		"colony":
			return _choose_colony_intention(agent)
		"vector":
			return _choose_vector_intention(agent)
		"wetland_engineer":
			return _choose_engineer_intention(agent)
	return {"type": "wait", "agent_id": agent["id"]}


func _choose_grazer_intention(agent: Dictionary) -> Dictionary:
	var agent_id := String(agent["id"])
	agent["hunger"] = minf(1.0, float(agent["hunger"]) + 0.08)
	agent["fear"] = maxf(0.0, float(agent["fear"]) - 0.08)
	if int(agent["digestion_ticks"]) > 0:
		agent["digestion_ticks"] = int(agent["digestion_ticks"]) - 1
		agent["move_cooldown"] = maxi(0, int(agent["move_cooldown"]) - 1)
		agents[agent_id] = agent
		var digesting_resource := String(agent["digesting_resource"])
		if int(agent["digestion_ticks"]) == 0 and float(agent["carried_material"].get(digesting_resource, 0.0)) > 0.0 and agent["cell"] != agent["last_feeding_cell"]:
			return {"type": "deposit", "agent_id": agent_id, "resource": "dead_biomass", "source_resource": digesting_resource}
		if agent["cell"] == agent["last_feeding_cell"]:
			return {"type": "move", "agent_id": agent_id, "cell": _roam_cell(agent)}
		return {"type": "wait", "agent_id": agent_id}
	var local_food := "rhizome" if ecology.resource_amount(agent["cell"], "rhizome") >= ecology.resource_amount(agent["cell"], "moss") else "moss"
	if float(agent["hunger"]) >= 0.65 and ecology.resource_amount(agent["cell"], local_food) >= 0.02:
		return {"type": "consume", "agent_id": agent_id, "resource": local_food, "amount": 0.12}
	if int(agent["move_cooldown"]) > 0:
		agent["move_cooldown"] = int(agent["move_cooldown"]) - 1
		agents[agent_id] = agent
		return {"type": "wait", "agent_id": agent_id}
	if float(agent["hunger"]) >= 0.65:
		var moss_cell := _strongest_resource_cell("moss")
		var rhizome_cell := _strongest_resource_cell("rhizome")
		var target := rhizome_cell if ecology.resource_amount(rhizome_cell, "rhizome") > ecology.resource_amount(moss_cell, "moss") else moss_cell
		return {"type": "move", "agent_id": agent_id, "cell": _step_toward(agent["cell"], target)}
	return {"type": "move", "agent_id": agent_id, "cell": _roam_cell(agent)}


func _choose_predator_intention(agent: Dictionary) -> Dictionary:
	var agent_id := String(agent["id"])
	agent["hunger"] = minf(1.0, float(agent["hunger"]) + 0.07)
	agent["fear"] = maxf(0.0, float(agent["fear"]) - 0.05)
	agents[agent_id] = agent
	var prey_id := _nearest_living_species(agent["cell"], "grazer")
	if prey_id.is_empty():
		return {"type": "move", "agent_id": agent_id, "cell": _roam_cell(agent)}
	var prey: Dictionary = agents[prey_id]
	if float(agent["fear"]) > 0.45:
		return {"type": "move", "agent_id": agent_id, "cell": _step_away(agent["cell"], prey["cell"])}
	if float(agent["hunger"]) >= 0.4 and _cell_distance(agent["cell"], prey["cell"]) <= 1:
		return {"type": "predate", "agent_id": agent_id, "prey_id": prey_id, "amount": 0.16}
	if int(agent["move_cooldown"]) > 0:
		agent["move_cooldown"] = int(agent["move_cooldown"]) - 1
		agents[agent_id] = agent
		return {"type": "wait", "agent_id": agent_id}
	return {"type": "move", "agent_id": agent_id, "cell": _step_toward(agent["cell"], prey["cell"])}


func _choose_colony_intention(agent: Dictionary) -> Dictionary:
	var agent_id := String(agent["id"])
	var home_cell: Vector2i = agent.get("home_cell", agent["cell"])
	var worker_cell: Vector2i = agent.get("worker_cell", home_cell)
	var worker_phase := String(agent.get("worker_phase", "idle"))
	agent["hunger"] = minf(1.0, float(agent["hunger"]) + 0.035)
	agent["brood"] = maxf(0.0, float(agent["brood"]) - 0.002)
	if int(agent["move_cooldown"]) > 0:
		agent["move_cooldown"] = int(agent["move_cooldown"]) - 1
		agents[agent_id] = agent
		return {"type": "wait", "agent_id": agent_id}
	agents[agent_id] = agent
	if worker_phase == "returning":
		if worker_cell == home_cell:
			return {"type": "colony_worker_return", "agent_id": agent_id}
		return {"type": "colony_worker_move", "agent_id": agent_id, "cell": _step_toward(worker_cell, home_cell), "phase": "returning"}
	if worker_phase == "outbound":
		var target: Vector2i = agent.get("worker_target", worker_cell)
		if worker_cell == target:
			var target_plant := String(agent.get("worker_load_resource", "moss"))
			return {"type": "colony_worker_gather", "agent_id": agent_id, "resource": target_plant, "amount": 0.018}
		return {"type": "colony_worker_move", "agent_id": agent_id, "cell": _step_toward(worker_cell, target), "phase": "outbound"}
	var detritus: float = ecology.resource_amount(home_cell, "dead_biomass")
	if detritus >= 0.025:
		return {"type": "colony_recycle", "agent_id": agent_id, "amount": 0.06}
	var moss_target := _strongest_resource_cell("moss")
	var rhizome_target := _strongest_resource_cell("rhizome")
	var moss_amount: float = ecology.resource_amount(moss_target, "moss")
	var rhizome_amount: float = ecology.resource_amount(rhizome_target, "rhizome")
	var resource := "rhizome" if rhizome_amount > moss_amount else "moss"
	var forage_target: Vector2i = rhizome_target if resource == "rhizome" else moss_target
	if maxf(moss_amount, rhizome_amount) < 0.02:
		agent["state"] = "hive idle"
		agents[agent_id] = agent
		return {"type": "wait", "agent_id": agent_id}
	return {"type": "colony_worker_depart", "agent_id": agent_id, "cell": forage_target, "resource": resource}


func _choose_vector_intention(agent: Dictionary) -> Dictionary:
	var agent_id := String(agent["id"])
	if int(agent["move_cooldown"]) > 0:
		agent["move_cooldown"] = int(agent["move_cooldown"]) - 1
		agents[agent_id] = agent
		return {"type": "wait", "agent_id": agent_id}
	if float(agent["pollen_load"]) > 0.02:
		if ecology.resource_amount(agent["cell"], "ground_bloom") + ecology.resource_amount(agent["cell"], "canopy_bloom") > 0.02:
			return {"type": "pollinate", "agent_id": agent_id, "amount": minf(0.08, float(agent["pollen_load"]))}
		var ground_target: Vector2i = _strongest_resource_cell("ground_bloom")
		var canopy_target: Vector2i = _strongest_resource_cell("canopy_bloom")
		var pollen_target: Vector2i = canopy_target if ecology.resource_amount(canopy_target, "canopy_bloom") >= ecology.resource_amount(ground_target, "ground_bloom") else ground_target
		return {"type": "move", "agent_id": agent_id, "cell": _step_toward(agent["cell"], pollen_target)}
	if float(agent["spore_load"]) > 0.02:
		var local_refuge: float = ecology.resource_amount(agent["cell"], "dead_biomass") * ecology.resource_amount(agent["cell"], "moisture")
		if local_refuge > 0.015:
			return {"type": "disperse_spores", "agent_id": agent_id, "amount": minf(0.08, float(agent["spore_load"]))}
		return {"type": "move", "agent_id": agent_id, "cell": _step_toward(agent["cell"], _strongest_resource_cell("dead_biomass"))}
	var flower_signal: float = ecology.resource_amount(agent["cell"], "ground_bloom") + ecology.resource_amount(agent["cell"], "canopy_bloom")
	if flower_signal > 0.02:
		var nectar_signal := flower_signal
		return {"type": "collect_pollen", "agent_id": agent_id, "amount": minf(0.08, nectar_signal * 0.25)}
	if ecology.resource_amount(agent["cell"], "fruiting") > 0.05:
		return {"type": "collect_spores", "agent_id": agent_id, "amount": minf(0.08, ecology.resource_amount(agent["cell"], "fruiting") * 0.18)}
	var ground_cell: Vector2i = _strongest_resource_cell("ground_bloom")
	var canopy_cell: Vector2i = _strongest_resource_cell("canopy_bloom")
	var target: Vector2i = ground_cell if ecology.resource_amount(ground_cell, "ground_bloom") >= ecology.resource_amount(canopy_cell, "canopy_bloom") else canopy_cell
	if ecology.resource_amount(target, "ground_bloom") + ecology.resource_amount(target, "canopy_bloom") <= 0.0:
		target = _strongest_resource_cell("fruiting")
	return {"type": "move", "agent_id": agent_id, "cell": _step_toward(agent["cell"], target)}


func _choose_engineer_intention(agent: Dictionary) -> Dictionary:
	var agent_id := String(agent["id"])
	if int(agent["move_cooldown"]) > 0:
		agent["move_cooldown"] = int(agent["move_cooldown"]) - 1
		agents[agent_id] = agent
		return {"type": "wait", "agent_id": agent_id}
	var carried_dead := float(agent["carried_material"].get("dead_biomass", 0.0))
	var carried_roots := float(agent["carried_material"].get("rhizome", 0.0))
	if carried_dead + carried_roots >= 0.04:
		var build_cell: Vector2i = agent.get("last_gather_cell", agent["cell"])
		if agent["cell"] == build_cell and ecology.downhill_neighbor(build_cell) != build_cell:
			var source: String = "dead_biomass" if carried_dead >= carried_roots else "rhizome"
			return {"type": "deposit", "agent_id": agent_id, "source_resource": source, "resource": "dam_material"}
		return {"type": "move", "agent_id": agent_id, "cell": _step_toward(agent["cell"], build_cell)}
	var building_source: String = "dead_biomass" if ecology.resource_amount(agent["cell"], "dead_biomass") >= ecology.resource_amount(agent["cell"], "rhizome") else "rhizome"
	if ecology.resource_amount(agent["cell"], building_source) >= 0.025:
		return {"type": "gather", "agent_id": agent_id, "resource": building_source, "amount": 0.07}
	var dead_cell: Vector2i = _strongest_resource_cell("dead_biomass")
	var root_cell: Vector2i = _strongest_resource_cell("rhizome")
	var target: Vector2i = dead_cell if ecology.resource_amount(dead_cell, "dead_biomass") >= ecology.resource_amount(root_cell, "rhizome") else root_cell
	return {"type": "move", "agent_id": agent_id, "cell": _step_toward(agent["cell"], target)}


func _resolve_intention(intention: Dictionary) -> void:
	var agent_id := String(intention["agent_id"])
	if not agents.has(agent_id) or not bool(agents[agent_id]["alive"]):
		return
	match String(intention["type"]):
		"wait":
			pass
		"move":
			_move_agent(agent_id, intention["cell"])
		"consume":
			_consume_environment(agent_id, String(intention["resource"]), float(intention["amount"]))
		"gather":
			_gather_material(agent_id, String(intention["resource"]), float(intention["amount"]))
		"deposit":
			_deposit_carried(agent_id, String(intention["source_resource"]), String(intention["resource"]))
		"colony_recycle":
			_colony_recycle(agent_id, float(intention["amount"]))
		"colony_worker_depart":
			_depart_colony_worker(agent_id, intention["cell"], String(intention["resource"]))
		"colony_worker_move":
			_move_colony_worker(agent_id, intention["cell"], String(intention["phase"]))
		"colony_worker_gather":
			_gather_colony_plant(agent_id, String(intention["resource"]), float(intention["amount"]))
		"colony_worker_return":
			_return_colony_plant(agent_id)
		"collect_pollen":
			_collect_pollen(agent_id, float(intention["amount"]))
		"pollinate":
			_pollinate(agent_id, float(intention["amount"]))
		"collect_spores":
			_collect_spores(agent_id, float(intention["amount"]))
		"disperse_spores":
			_disperse_spores(agent_id, float(intention["amount"]))
		"predate":
			_predate(agent_id, String(intention["prey_id"]), float(intention["amount"]))
		"reproduce":
			_reproduce(agent_id, String(intention["mate_id"]))


func _move_agent(agent_id: String, destination: Vector2i) -> void:
	var agent: Dictionary = agents[agent_id]
	var origin: Vector2i = agent["cell"]
	var bounded := _bounded_cell(destination)
	agent["cell"] = bounded
	var moving_states := {"grazer": "roaming", "predator": "hunting", "colony": "foraging", "vector": "flying", "wetland_engineer": "hauling"}
	agent["state"] = moving_states.get(agent["species"], "moving")
	var pacing := {"grazer": 15, "predator": 8, "colony": 10, "vector": 2, "wetland_engineer": 11}
	agent["move_cooldown"] = pacing.get(agent["species"], 6)
	agents[agent_id] = agent
	if origin != bounded:
		_emit("organism.moved", agent_id, {"from": origin, "to": bounded})


func _consume_environment(agent_id: String, resource: String, requested: float) -> void:
	var agent: Dictionary = agents[agent_id]
	var carried_before := float(agent["carried_material"].get(resource, 0.0))
	var consumed: float = ecology.consume_resource(agent["cell"], resource, requested)
	agent["carried_material"][resource] = carried_before + consumed
	agent["hunger"] = maxf(0.0, float(agent["hunger"]) - consumed * 6.5)
	agent["digestion_ticks"] = 3
	agent["digesting_resource"] = resource
	agent["last_feeding_cell"] = agent["cell"]
	agent["state"] = "digesting"
	agents[agent_id] = agent
	_check_transfer(consumed, float(agent["carried_material"][resource]) - carried_before, "environment_to_%s" % agent_id)
	if consumed > 0.0:
		_emit("organism.%s_consumed" % resource, agent_id, {"cell": agent["cell"], "amount": consumed})


func _gather_material(agent_id: String, resource: String, requested: float) -> void:
	var agent: Dictionary = agents[agent_id]
	var before := float(agent["carried_material"].get(resource, 0.0))
	var gathered: float = ecology.consume_resource(agent["cell"], resource, requested)
	agent["carried_material"][resource] = before + gathered
	agent["last_gather_cell"] = agent["cell"]
	agent["state"] = "gathering"
	agents[agent_id] = agent
	_check_transfer(gathered, float(agent["carried_material"][resource]) - before, "environment_to_%s" % agent_id)
	if gathered > 0.0:
		_emit("organism.material_gathered", agent_id, {"cell": agent["cell"], "resource": resource, "amount": gathered})


func _colony_recycle(agent_id: String, requested: float) -> void:
	var agent: Dictionary = agents[agent_id]
	var home_cell: Vector2i = agent.get("home_cell", agent["cell"])
	var removed: float = ecology.consume_resource(home_cell, "dead_biomass", requested)
	var returned := removed * 0.72
	var accepted: Dictionary = ecology.add_resources(home_cell, {"nutrients": returned})
	var deposited := float(accepted.get("nutrients", 0.0))
	var metabolic_loss := removed - deposited
	agent["hunger"] = maxf(0.0, float(agent["hunger"]) - removed * 5.0)
	agent["brood"] = minf(1.0, float(agent["brood"]) + metabolic_loss * 0.5)
	agent["state"] = "hive recycling"
	agent["move_cooldown"] = 8
	agents[agent_id] = agent
	if removed > 0.0:
		_emit("organism.detritus_recycled", agent_id, {"cell": home_cell, "removed": removed, "nutrients": deposited, "metabolic_loss": metabolic_loss})


func _depart_colony_worker(agent_id: String, target: Vector2i, resource: String) -> void:
	var agent: Dictionary = agents[agent_id]
	var home_cell: Vector2i = agent.get("home_cell", agent["cell"])
	agent["cell"] = home_cell
	agent["worker_cell"] = home_cell
	agent["worker_target"] = _bounded_cell(target)
	agent["worker_phase"] = "outbound"
	agent["worker_load_resource"] = resource
	agent["worker_load"] = 0.0
	agent["move_cooldown"] = 12
	agent["state"] = "workers outbound"
	agents[agent_id] = agent
	_emit("organism.colony_worker_departed", agent_id, {"home_cell": home_cell, "target_cell": agent["worker_target"], "resource": resource})


func _move_colony_worker(agent_id: String, destination: Vector2i, phase: String) -> void:
	var agent: Dictionary = agents[agent_id]
	var origin: Vector2i = agent.get("worker_cell", agent["cell"])
	var bounded := _bounded_cell(destination)
	agent["worker_cell"] = bounded
	agent["worker_phase"] = phase
	agent["move_cooldown"] = 12
	agent["state"] = "workers " + phase
	agents[agent_id] = agent
	if origin != bounded:
		_emit("organism.colony_worker_moved", agent_id, {"from": origin, "to": bounded, "phase": phase, "home_cell": agent["home_cell"]})


func _gather_colony_plant(agent_id: String, resource: String, requested: float) -> void:
	var agent: Dictionary = agents[agent_id]
	var worker_cell: Vector2i = agent.get("worker_cell", agent["cell"])
	var gathered: float = ecology.consume_resource(worker_cell, resource, requested)
	agent["worker_load_resource"] = resource
	agent["worker_load"] = float(agent.get("worker_load", 0.0)) + gathered
	agent["worker_phase"] = "returning"
	agent["move_cooldown"] = 12
	agent["state"] = "workers returning"
	agents[agent_id] = agent
	if gathered > 0.0:
		_emit("organism.colony_plant_gathered", agent_id, {"cell": worker_cell, "resource": resource, "amount": gathered, "home_cell": agent["home_cell"]})


func _return_colony_plant(agent_id: String) -> void:
	var agent: Dictionary = agents[agent_id]
	var home_cell: Vector2i = agent.get("home_cell", agent["cell"])
	var offered: float = maxf(0.0, float(agent.get("worker_load", 0.0)))
	var accepted: Dictionary = ecology.add_resources(home_cell, {"dead_biomass": offered})
	var deposited := float(accepted.get("dead_biomass", 0.0))
	agent["worker_load"] = offered - deposited
	agent["worker_cell"] = home_cell
	agent["worker_target"] = home_cell
	agent["worker_phase"] = "idle"
	agent["move_cooldown"] = 12
	agent["state"] = "hive receiving"
	agent["hunger"] = maxf(0.0, float(agent["hunger"]) - deposited * 3.0)
	agents[agent_id] = agent
	_check_transfer(deposited, offered - float(agent["worker_load"]), "%s_worker_to_hive" % agent_id)
	if deposited > 0.0:
		_emit("organism.colony_plant_returned", agent_id, {"home_cell": home_cell, "source_resource": agent["worker_load_resource"], "amount": deposited})


func _collect_pollen(agent_id: String, amount: float) -> void:
	var agent: Dictionary = agents[agent_id]
	agent["pollen_load"] = minf(0.12, float(agent["pollen_load"]) + maxf(0.0, amount))
	agent["state"] = "collecting"
	agents[agent_id] = agent
	_emit("organism.pollen_collected", agent_id, {"cell": agent["cell"], "amount": amount})


func _pollinate(agent_id: String, requested: float) -> void:
	var agent: Dictionary = agents[agent_id]
	var offered := minf(float(agent["pollen_load"]), maxf(0.0, requested))
	var accepted: Dictionary = ecology.add_resources(agent["cell"], {"pollination": offered})
	var deposited := float(accepted.get("pollination", 0.0))
	agent["pollen_load"] = float(agent["pollen_load"]) - deposited
	agent["state"] = "pollinating"
	agents[agent_id] = agent
	if deposited > 0.0:
		_emit("organism.patch_pollinated", agent_id, {"cell": agent["cell"], "amount": deposited})


func _collect_spores(agent_id: String, amount: float) -> void:
	var agent: Dictionary = agents[agent_id]
	agent["spore_load"] = minf(0.12, float(agent["spore_load"]) + maxf(0.0, amount))
	agent["state"] = "spore_collecting"
	agents[agent_id] = agent
	_emit("organism.fungal_spores_collected", agent_id, {"cell": agent["cell"], "amount": amount})


func _disperse_spores(agent_id: String, requested: float) -> void:
	var agent: Dictionary = agents[agent_id]
	var offered := minf(float(agent["spore_load"]), maxf(0.0, requested))
	var accepted: Dictionary = ecology.add_resources(agent["cell"], {"fungal_spores": offered})
	var deposited := float(accepted.get("fungal_spores", 0.0))
	agent["spore_load"] = float(agent["spore_load"]) - deposited
	agent["state"] = "spore_dispersing"
	agents[agent_id] = agent
	if deposited > 0.0:
		_emit("organism.fungal_spores_distributed", agent_id, {"cell": agent["cell"], "amount": deposited})


func _deposit_carried(agent_id: String, source_resource: String, target_resource: String) -> void:
	var agent: Dictionary = agents[agent_id]
	var available := float(agent["carried_material"].get(source_resource, 0.0))
	if available <= 0.0:
		return
	var accepted: Dictionary = ecology.add_resources(agent["cell"], {target_resource: available})
	var deposited := float(accepted.get(target_resource, 0.0))
	agent["carried_material"][source_resource] = available - deposited
	agent["state"] = "roaming"
	agents[agent_id] = agent
	_check_transfer(deposited, available - float(agent["carried_material"][source_resource]), "%s_to_environment" % agent_id)
	if deposited > 0.0:
		_emit("organism.material_deposited", agent_id, {"cell": agent["cell"], "source": source_resource, "resource": target_resource, "amount": deposited})


func _predate(predator_id: String, prey_id: String, requested: float) -> void:
	if not agents.has(prey_id) or not bool(agents[prey_id]["alive"]):
		return
	var predator: Dictionary = agents[predator_id]
	var prey: Dictionary = agents[prey_id]
	var removed := minf(float(prey["body_biomass"]), requested)
	var carried_before := float(predator["carried_material"].get("animal_biomass", 0.0))
	prey["body_biomass"] = float(prey["body_biomass"]) - removed
	predator["carried_material"]["animal_biomass"] = carried_before + removed
	predator["hunger"] = maxf(0.0, float(predator["hunger"]) - removed * 4.0)
	predator["state"] = "feeding"
	agents[predator_id] = predator
	agents[prey_id] = prey
	_check_transfer(removed, float(predator["carried_material"]["animal_biomass"]) - carried_before, "%s_to_%s" % [prey_id, predator_id])
	_emit("organism.predation", predator_id, {"prey_id": prey_id, "amount": removed})
	if float(prey["body_biomass"]) <= 0.0001:
		prey["alive"] = false
		prey["state"] = "dead"
		agents[prey_id] = prey
		_emit("organism.died", prey_id, {"cause": "predation", "predator_id": predator_id})


func _reproduce(parent_id: String, mate_id: String) -> void:
	if parent_id == mate_id or not agents.has(parent_id) or not agents.has(mate_id):
		return
	var parent: Dictionary = agents[parent_id]
	var mate: Dictionary = agents[mate_id]
	if not bool(parent["alive"]) or not bool(mate["alive"]) or parent["species"] != mate["species"]:
		return
	if float(parent["reproductive_readiness"]) < 1.0 or float(mate["reproductive_readiness"]) < 1.0:
		return
	if _cell_distance(parent["cell"], mate["cell"]) > 1:
		return
	var contribution := minf(0.12, minf(float(parent["body_biomass"]) - 0.35, float(mate["body_biomass"]) - 0.35))
	if contribution <= 0.0:
		return
	parent["body_biomass"] = float(parent["body_biomass"]) - contribution
	mate["body_biomass"] = float(mate["body_biomass"]) - contribution
	parent["reproductive_readiness"] = 0.0
	mate["reproductive_readiness"] = 0.0
	var child_id := "%s:offspring:%03d" % [String(parent["species"]), _next_birth_sequence]
	_next_birth_sequence += 1
	agents[parent_id] = parent
	agents[mate_id] = mate
	var child_state := {
		"cell": parent["cell"],
		"hunger": 0.2,
		"body_biomass": contribution * 2.0,
		"reproductive_readiness": 0.0,
		"generation": maxi(int(parent["generation"]), int(mate["generation"])) + 1,
		"parents": [parent_id, mate_id]
	}
	register_agent(parent["species"], child_id, child_state)
	_emit("organism.reproduced", child_id, {"parents": [parent_id, mate_id], "species": parent["species"], "body_biomass": contribution * 2.0})


func _ready_mate_id(agent: Dictionary) -> String:
	var ids := agents.keys()
	ids.sort()
	for candidate_id in ids:
		if candidate_id == agent["id"]:
			continue
		var candidate: Dictionary = agents[candidate_id]
		if bool(candidate["alive"]) and candidate["species"] == agent["species"] and float(candidate["reproductive_readiness"]) >= 1.0 and _cell_distance(agent["cell"], candidate["cell"]) <= 1:
			return candidate_id
	return ""


func _deposit_to_environment(cell: Vector2i, resource: String, amount: float, source: String) -> float:
	var accepted: Dictionary = ecology.add_resources(cell, {resource: amount})
	var deposited := float(accepted.get(resource, 0.0))
	if deposited > amount + 0.000001:
		conservation_violations.append("%s_to_environment accepted more than offered" % source)
	return deposited


func _strongest_resource_cell(resource: String) -> Vector2i:
	var strongest := Vector2i.ZERO
	var strongest_amount := -1.0
	for y in range(ecology.HEIGHT):
		for x in range(ecology.WIDTH):
			var cell := Vector2i(x, y)
			var amount: float = ecology.resource_amount(cell, resource)
			if amount > strongest_amount:
				strongest_amount = amount
				strongest = cell
	return strongest


func _nearest_living_species(origin: Vector2i, species: String) -> String:
	var nearest_id := ""
	var nearest_distance := 999999
	var ids := agents.keys()
	ids.sort()
	for agent_id in ids:
		var candidate: Dictionary = agents[agent_id]
		if not bool(candidate["alive"]) or candidate["species"] != species:
			continue
		var distance := _cell_distance(origin, candidate["cell"])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = agent_id
	return nearest_id


func _roam_cell(agent: Dictionary) -> Vector2i:
	var heading: Vector2i = agent["heading"]
	var steps := int(agent["heading_steps"])
	if steps <= 0 or not _cell_is_viable(agent["cell"] + heading):
		var direction_index := posmod(seed + tick + String(agent["id"]).hash(), DIRECTIONS.size())
		heading = DIRECTIONS[direction_index]
		steps = 3 + posmod(seed + tick, 4)
	agent["heading"] = heading
	agent["heading_steps"] = steps - 1
	agents[agent["id"]] = agent
	var candidate: Vector2i = agent["cell"] + heading
	return candidate if _cell_is_viable(candidate) else agent["cell"]


func _step_toward(origin: Vector2i, target: Vector2i) -> Vector2i:
	return _bounded_cell(origin + Vector2i(signi(target.x - origin.x), signi(target.y - origin.y)))


func _step_away(origin: Vector2i, threat: Vector2i) -> Vector2i:
	return _bounded_cell(origin + Vector2i(signi(origin.x - threat.x), signi(origin.y - threat.y)))


func _cell_is_viable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= ecology.WIDTH or cell.y < 0 or cell.y >= ecology.HEIGHT:
		return false
	return ecology.cell_snapshot(cell.x, cell.y)["toxicity"] < 0.9


func _bounded_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(clampi(cell.x, 0, ecology.WIDTH - 1), clampi(cell.y, 0, ecology.HEIGHT - 1))


func _cell_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _check_transfer(removed: float, added: float, label: String) -> void:
	if not is_equal_approx(removed, added):
		conservation_violations.append("%s removed %.6f but added %.6f" % [label, removed, added])


func _emit(taxonomy: String, subject: String, facts := {}) -> void:
	event_history.append({
		"id": "animal-evt-%04d" % _next_event_sequence,
		"tick": tick,
		"taxonomy": taxonomy,
		"subject": subject,
		"facts": facts.duplicate(true)
	})
	_next_event_sequence += 1
