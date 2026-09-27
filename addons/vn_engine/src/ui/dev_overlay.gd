class_name VNEngineDevOverlay
extends Control

const REFRESH_INTERVAL: float = 0.25
const MAX_FLAGS_TEXT_LEN: int = 200

var _accum: float = 0.0

@onready var label: Label = get_node_or_null("%DevOverlayLabel") as Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not visible:
		return
	_accum += delta
	if _accum < REFRESH_INTERVAL:
		return
	_accum = 0.0
	_refresh()


func _refresh() -> void:
	label.text = _build_text()


func _build_text() -> String:
	var lines: PackedStringArray = PackedStringArray()

	lines.append("FPS: %d" % Engine.get_frames_per_second())

	var version_info: Dictionary = Engine.get_version_info()
	lines.append("Godot: %s" % str(version_info.get("string", "?")))
	lines.append("Engine: %s" % _engine_version())

	var app_version: String = "-"
	var game: VNEngineGame = VNEngineMain.game()
	if game.manifest != null:
		app_version = game.manifest.version
	lines.append("Game: %s" % app_version)

	var root: VNEngineMain = VNEngineMain.instance()

	var screen_id_text: String = "-"
	var chapter_text: String = "-"
	var node_text: String = "-"
	var line_text: String = "-"
	var flags_text: String = "-"

	var id: StringName = root.screen_stack.current_id()
	if id != &"":
		screen_id_text = String(id)

	var screen: VNEngineScreen = root.screen_stack.current_screen()
	var stage: VNEngineStageScreen = screen as VNEngineStageScreen
	if stage != null:
		var runner: VNEngineStoryRunner = stage.story_runner
		if runner.state.chapter_id != "":
			chapter_text = runner.state.chapter_id
		if runner.state.current_node_id != "":
			node_text = runner.state.current_node_id

		var node: VNEngineStoryNode = runner.get_current_node()
		if node != null:
			line_text = str(node.line)

		flags_text = _format_flags(runner.state.flags)

	lines.append("Screen: %s" % screen_id_text)
	lines.append("Chapter: %s" % chapter_text)
	lines.append("Node: %s" % node_text)
	lines.append("Line: %s" % line_text)
	lines.append("Content root: %s" % VNEnginePaths.content_root())
	lines.append("Flags: %s" % flags_text)

	return "\n".join(lines)


func _format_flags(flags: Dictionary) -> String:
	if flags.is_empty():
		return "(none)"

	var flag_list: VNEngineFlagList = VNEngineMain.game().get_flag_list()
	var parts: PackedStringArray = PackedStringArray()
	for key in flags.keys():
		var label: String = str(key)
		if flag_list != null:
			var flag: VNEngineFlagDef = flag_list.find(label)
			if flag != null and flag.debug_name != "":
				label = flag.debug_name
		parts.append("%s=%s" % [label, str(flags[key])])

	var joined: String = ", ".join(parts)
	if joined.length() > MAX_FLAGS_TEXT_LEN:
		joined = joined.substr(0, MAX_FLAGS_TEXT_LEN) + "…"
	return joined


static var _cached_engine_version: String = ""


static func _engine_version() -> String:
	if _cached_engine_version == "":
		var cfg: ConfigFile = ConfigFile.new()
		if cfg.load("res://addons/vn_engine/plugin.cfg") == OK:
			_cached_engine_version = str(cfg.get_value("plugin", "version", "?"))
		else:
			_cached_engine_version = "?"
	return _cached_engine_version
