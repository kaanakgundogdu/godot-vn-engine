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
var bg_view: Dictionary = {}
var audio: Dictionary = {}

var characters: Dictionary = {}
var last_speaker: String = ""

var seen_choices: Dictionary = {}

var call_stack: Array[Dictionary] = []

var history: Array[Dictionary] = []

var flow_path: Array[String] = []

var text_mode: String = ""

var nvl_page: Array[Dictionary] = []

var rng_seed: int = 0
var rng_state: int = 0

func seed_rng(new_seed: int) -> void:
	rng_seed = new_seed
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = new_seed
	rng_state = rng.state

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
		"bg_view": bg_view.duplicate(true),
		"audio": audio.duplicate(true),
		"characters": characters.duplicate(true),
		"last_speaker": last_speaker,
		"seen_choices": seen_choices.duplicate(true),
		"call_stack": call_stack.duplicate(true),
		"flow_path": flow_path.duplicate(),
		"text_mode": text_mode,
		"nvl_page": nvl_page.duplicate(true),
		"rng_seed": str(rng_seed),
		"rng_state": str(rng_state),
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
	var new_bg_view: Dictionary = data.get("bg_view", {})
	bg_view = new_bg_view.duplicate(true)

	var new_audio: Dictionary = data.get("audio", {})
	audio = new_audio.duplicate(true)

	var new_characters: Dictionary = data.get("characters", {})
	characters = new_characters.duplicate(true)

	last_speaker = data.get("last_speaker", "")

	var new_seen_choices: Dictionary = data.get("seen_choices", {})
	seen_choices = new_seen_choices.duplicate(true)

	call_stack = _to_dict_array(data.get("call_stack", []))

	flow_path.clear()
	var new_flow_path: Variant = data.get("flow_path", [])
	if new_flow_path is Array:
		for item in new_flow_path:
			flow_path.append(String(item))

	text_mode = String(data.get("text_mode", ""))
	nvl_page = _to_dict_array(data.get("nvl_page", []))
	rng_seed = str(data.get("rng_seed", "0")).to_int()
	rng_state = str(data.get("rng_state", "0")).to_int()

	if data.has("history"):
		history = _to_dict_array(data.get("history", []))

func _to_dict_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				result.append(item)
	return result
