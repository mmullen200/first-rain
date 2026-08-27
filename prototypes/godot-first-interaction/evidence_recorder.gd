class_name PrototypeEvidenceRecorder
extends RefCounted

# THROWAWAY PROTOTYPE.
# In-memory evidence contract for reconstructing a deterministic run. Gameplay
# records facts here; presentation can read them but never becomes their source.

const CONTRACT_VERSION := 1

var run_id := ""
var commands: Array[Dictionary] = []
var events: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var _next_sequence := 1


func begin_run(seed: int, initial_state: Dictionary) -> void:
	run_id = "run-%d" % seed
	commands.clear()
	events.clear()
	checkpoints.clear()
	_next_sequence = 1
	checkpoint(0, "run_started", initial_state)


func record_command(tick: int, verb: String, target: String, facts := {}) -> String:
	var id := _new_id("cmd")
	commands.append({
		"id": id,
		"tick": tick,
		"verb": verb,
		"target": target,
		"facts": facts.duplicate(true)
	})
	return id


func record_event(tick: int, taxonomy: String, subject: String, causes := [], facts := {}) -> String:
	var id := _new_id("evt")
	events.append({
		"id": id,
		"tick": tick,
		"taxonomy": taxonomy,
		"subject": subject,
		"causes": causes.duplicate(),
		"facts": facts.duplicate(true)
	})
	return id


func checkpoint(tick: int, reason: String, state: Dictionary) -> String:
	var id := _new_id("snap")
	checkpoints.append({
		"id": id,
		"version": CONTRACT_VERSION,
		"tick": tick,
		"reason": reason,
		"state": state.duplicate(true)
	})
	return id


func causal_episode(event_id: String) -> Array[Dictionary]:
	var by_id := {}
	for command in commands:
		by_id[command["id"]] = command
	for event in events:
		by_id[event["id"]] = event
	var result: Array[Dictionary] = []
	var visited := {}
	_collect_causes(event_id, by_id, visited, result)
	return result


func debug_view(selection_from_end := 0, limit := 9) -> PackedStringArray:
	var lines := PackedStringArray([
		"EVIDENCE / CONTRACT v%d / %s" % [CONTRACT_VERSION, run_id],
		"%d commands  %d events  %d checkpoints" % [commands.size(), events.size(), checkpoints.size()]
	])
	if events.is_empty():
		lines.append("No domain events yet. Commands remain distinct from outcomes.")
		return lines
	var selected_index: int = clampi(events.size() - 1 - selection_from_end, 0, events.size() - 1)
	var selected: Dictionary = events[selected_index]
	lines.append("SELECTED %s  tick %d  %s / %s" % [selected["id"], selected["tick"], selected["taxonomy"], selected["subject"]])
	lines.append("CAUSE CHAIN")
	for item in causal_episode(selected["id"]):
		lines.append("  %s  t%03d  %s" % [item["id"], item["tick"], _item_label(item)])
	lines.append("RECENT EVENTS")
	var start := maxi(0, events.size() - limit)
	for index in range(start, events.size()):
		var marker := ">" if index == selected_index else " "
		var event: Dictionary = events[index]
		lines.append("%s %s t%03d %s / %s" % [marker, event["id"], event["tick"], event["taxonomy"], event["subject"]])
	return lines


func _collect_causes(id: String, by_id: Dictionary, visited: Dictionary, result: Array[Dictionary]) -> void:
	if visited.has(id) or not by_id.has(id):
		return
	visited[id] = true
	var item: Dictionary = by_id[id]
	for cause_id in item.get("causes", []):
		_collect_causes(cause_id, by_id, visited, result)
	result.append(item)


func _item_label(item: Dictionary) -> String:
	if item.has("verb"):
		return "COMMAND %s -> %s" % [item["verb"], item["target"]]
	return "%s -> %s" % [item["taxonomy"], item["subject"]]


func _new_id(prefix: String) -> String:
	var id := "%s-%04d" % [prefix, _next_sequence]
	_next_sequence += 1
	return id
