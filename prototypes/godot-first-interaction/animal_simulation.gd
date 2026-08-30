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


func _init(ecology_model = null, simulation_seed := 1) -> void:
	ecology = ecology_model
	seed = simulation_seed


func register_agent(species: String, stable_id: String, initial_state := {}) -> bool:
	if ecology == null or stable_id.is_empty() or agents.has(stable_id):
		return false
	if species != "grazer" and species != "predator":
		return false
	var cell: Vector2i = initial_state.get("cell", Vector2i.ZERO)
	var agent := {
		"id": stable_id,
		"species": species,
		"cell": _bounded_cell(cell),
		"alive": true,
		"state": "seeking" if species == "grazer" else "hunting",
		"hunger": float(initial_state.get("hunger", 1.0)),
		"body_biomass": float(initial_state.get("body_biomass", 1.0)),
		"carried_material": initial_state.get("carried_material", {}).duplicate(true),
		"digestion_ticks": int(initial_state.get("digestion_ticks", 0)),
		"last_feeding_cell": initial_state.get("last_feeding_cell", Vector2i(-1, -1)),
		"heading": initial_state.get("heading", Vector2i(1, 0)),
		"heading_steps": int(initial_state.get("heading_steps", 4)),
		"fear": float(initial_state.get("fear", 0.0))
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
	if agent["species"] == "grazer":
		return _choose_grazer_intention(agent)
	return _choose_predator_intention(agent)


func _choose_grazer_intention(agent: Dictionary) -> Dictionary:
	var agent_id := String(agent["id"])
	agent["hunger"] = minf(1.0, float(agent["hunger"]) + 0.08)
	agent["fear"] = maxf(0.0, float(agent["fear"]) - 0.08)
	if int(agent["digestion_ticks"]) > 0:
		agent["digestion_ticks"] = int(agent["digestion_ticks"]) - 1
		agents[agent_id] = agent
		if int(agent["digestion_ticks"]) == 0 and float(agent["carried_material"].get("moss", 0.0)) > 0.0 and agent["cell"] != agent["last_feeding_cell"]:
			return {"type": "deposit", "agent_id": agent_id, "resource": "dead_biomass", "source_resource": "moss"}
		return {"type": "move", "agent_id": agent_id, "cell": _roam_cell(agent)}
	if float(agent["hunger"]) >= 0.65 and ecology.resource_amount(agent["cell"], "moss") >= 0.02:
		return {"type": "consume", "agent_id": agent_id, "resource": "moss", "amount": 0.12}
	if float(agent["hunger"]) >= 0.65:
		return {"type": "move", "agent_id": agent_id, "cell": _step_toward(agent["cell"], _strongest_resource_cell("moss"))}
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
	return {"type": "move", "agent_id": agent_id, "cell": _step_toward(agent["cell"], prey["cell"])}


func _resolve_intention(intention: Dictionary) -> void:
	var agent_id := String(intention["agent_id"])
	if not agents.has(agent_id) or not bool(agents[agent_id]["alive"]):
		return
	match String(intention["type"]):
		"move":
			_move_agent(agent_id, intention["cell"])
		"consume":
			_consume_environment(agent_id, String(intention["resource"]), float(intention["amount"]))
		"deposit":
			_deposit_carried(agent_id, String(intention["source_resource"]), String(intention["resource"]))
		"predate":
			_predate(agent_id, String(intention["prey_id"]), float(intention["amount"]))


func _move_agent(agent_id: String, destination: Vector2i) -> void:
	var agent: Dictionary = agents[agent_id]
	var origin: Vector2i = agent["cell"]
	var bounded := _bounded_cell(destination)
	agent["cell"] = bounded
	agent["state"] = "roaming" if agent["species"] == "grazer" else "hunting"
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
	agent["last_feeding_cell"] = agent["cell"]
	agent["state"] = "digesting"
	agents[agent_id] = agent
	_check_transfer(consumed, float(agent["carried_material"][resource]) - carried_before, "environment_to_%s" % agent_id)
	if consumed > 0.0:
		_emit("organism.%s_consumed" % resource, agent_id, {"cell": agent["cell"], "amount": consumed})


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
