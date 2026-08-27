extends SceneTree

const EvidenceRecorder = preload("res://evidence_recorder.gd")


func _init() -> void:
	var recorder = EvidenceRecorder.new()
	recorder.begin_run(17, {"ecology_tick": 0})
	var command_id: String = recorder.record_command(0, "water", "hollow", {"doses": 1})
	var intervention_id: String = recorder.record_event(0, "intervention.water_added", "cell:4,3", [command_id])
	var growth_id: String = recorder.record_event(8, "ecology.moss_awakened", "cell:4,3", [intervention_id])
	recorder.checkpoint(8, "episode_boundary", {"moss_cells": 4})

	var episode: Array[Dictionary] = recorder.causal_episode(growth_id)
	if episode.size() != 3:
		_fail("causal episode did not include command, intervention, and ecological outcome")
	if episode[0]["id"] != command_id or episode[2]["id"] != growth_id:
		_fail("causal episode was not ordered from root cause to outcome")
	if recorder.checkpoints[1]["version"] != 1:
		_fail("checkpoint did not carry the contract version")
	var debug_text := "\n".join(recorder.debug_view())
	if not debug_text.contains("COMMAND water -> hollow") or not debug_text.contains("ecology.moss_awakened"):
		_fail("debug view did not expose the same causal evidence as the recorder interface")
	print("PASS: evidence recorder preserves commands, causal events, versioned checkpoints, and observer debug output")
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL: " + message)
	quit(1)
