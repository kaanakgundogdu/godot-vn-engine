extends RefCounted
class_name VNEngineStoryState


const MAX_HISTORY := 200

var current_file: String = ""
var current_node_id: String = ""
var chapter_id: String = ""
var playtime_sec: int = 0
var flags: Dictionary = {}

var bg: String = ""
var cg: String = ""
var audio: Dictionary = {}

var characters: Dictionary = {}
var last_speaker: String = ""

var seen_choices: Dictionary = {}

var call_stack: Array[Dictionary] = []

var history: Array[Dictionary] = []

func set_flag(flag_name: String, value: Variant) -> void:
	flags[flag_name.to_lower()] = value

func get_flag(flag_name: String, default_value: Variant = false) -> Variant:
	return flags.get(flag_name.to_lower(), default_value)

func has_flag(flag_name: String) -> bool:
	return flags.has(flag_name.to_lower())

func to_dict(include_history: bool = true) -> Dictionary:
	var data: Dictionary = {
		"current_file": current_file,
		"current_node_id": current_node_id,
		"chapter_id": chapter_id,
		"playtime_sec": playtime_sec,
		"flags": flags.duplicate(true),
		"bg": bg,
		"cg": cg,
		"audio": audio.duplicate(true),
		"characters": characters.duplicate(true),
		"last_speaker": last_speaker,
		"seen_choices": seen_choices.duplicate(true),
		"call_stack": call_stack.duplicate(true),
	}
	if include_history:
		data["history"] = history.duplicate(true)
	return data

func from_dict(data: Dictionary) -> void:
	current_file = data.get("current_file", "")
	current_node_id = data.get("current_node_id", "")
	chapter_id = data.get("chapter_id", "")
	playtime_sec = int(data.get("playtime_sec", 0))

	var new_flags: Dictionary = data.get("flags", {})
	flags = new_flags.duplicate(true)

	bg = data.get("bg", "")
	cg = data.get("cg", "")

	var new_audio: Dictionary = data.get("audio", {})
	audio = new_audio.duplicate(true)

	var new_characters: Dictionary = data.get("characters", {})
	characters = new_characters.duplicate(true)

	last_speaker = data.get("last_speaker", "")

	var new_seen_choices: Dictionary = data.get("seen_choices", {})
	seen_choices = new_seen_choices.duplicate(true)

	call_stack = _to_dict_array(data.get("call_stack", []))

	if data.has("history"):
		history = _to_dict_array(data.get("history", []))

func _to_dict_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				result.append(item)
	return result
