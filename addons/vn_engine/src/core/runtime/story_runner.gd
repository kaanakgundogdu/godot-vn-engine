extends Node
class_name VNEngineStoryRunner


signal dialog_started(node: VNEngineStoryNode)
signal choices_requested(choices: Array[VNEngineChoiceOption])
signal story_ended()
signal state_restored(state: VNEngineStoryState)

signal parse_diagnostics_ready(diagnostics: Array)

signal mode_changed

enum EndReason { SCRIPT_EXHAUSTED, EXPLICIT_END, RUNAWAY_GUARD }

var end_reason: int = EndReason.SCRIPT_EXHAUSTED
var end_ending_id: String = ""

var _ended: bool = false

func end_story(reason: int = EndReason.SCRIPT_EXHAUSTED, ending_id: String = "") -> void:
	if _ended:
		return
	_ended = true
	end_reason = reason
	end_ending_id = ending_id
	story_ended.emit()

var state: VNEngineStoryState = VNEngineStoryState.new()

var history_stack: VNEngineHistoryStack = VNEngineHistoryStack.new()

var script_res: VNEngineStoryScript
var current_index: int = -1

var bus: VNEngineCommandBus
var ctx: VNEngineCommandContext

var flag_list: VNEngineFlagList = null

var _playtime_accum: float = 0.0

var _jumped: bool = false

var _consecutive_logic_count: int = 0

var is_auto: bool = false
var is_skip: bool = false
var is_input_locked: bool = false

var pending_choice_timer: Dictionary = {}

const DEFERRED_COMMANDS := ["jump", "jump_if", "call", "return", "scene", "end", "goto_chapter", "credits"]

func _init() -> void:
	ctx = VNEngineCommandContext.new()
	bus = VNEngineCommandBus.new()
	ctx.runner = self
	ctx.bus = bus
	ctx.state = state
	_init_assets()
	_register_commands()

func _init_assets() -> void:
	ctx.assets = VNEngineAssetResolver.new()

	var asset_map_path: String = VNEnginePaths.asset_map()
	if not ResourceLoader.exists(asset_map_path):
		VNEngineLog.warn("StoryRunner", "'%s' does not exist yet, AssetResolver will stay empty" % asset_map_path)
		return

	var asset_map: VNEngineAssetMap = load(asset_map_path) as VNEngineAssetMap
	if asset_map == null:
		VNEngineLog.warn("StoryRunner", "Failed to load '%s', AssetResolver will stay empty" % asset_map_path)
		return

	ctx.assets.load_map(asset_map)

func _register_commands() -> void:
	VNEngineCommandRegistry.register_all(bus)

func register_manager(manager: Node) -> void:
	if manager is VNEngineBackgroundSystem:
		ctx.background = manager
	elif manager is VNEngineCharacterLayer:
		ctx.characters = manager
	elif manager is VNEngineAudioSystem:
		ctx.audio = manager
	elif manager is VNEngineVideoSystem:
		ctx.video = manager
	elif manager is VNEngineCameraSystem:
		ctx.camera = manager
	elif manager is VNEngineDialogUI:
		ctx.dialog_ui = manager

func start_story(file_path: String, start_index: int = 0) -> void:
	if not _load_script(file_path):
		return
	history_stack.clear()
	play_node(start_index)

func _load_script(file_path: String) -> bool:
	script_res = VNEngineMain.game().take_preparsed_script(file_path)
	if script_res == null:
		script_res = VNEngineScenarioParser.parse_file(file_path, flag_list)
	ctx.script_res = script_res

	if script_res.has_errors():
		VNEngineLog.warn("StoryRunner", "'%s' has parse errors:" % file_path)
		for diag in script_res.diagnostics:
			if diag.severity == VNEngineParseDiagnostic.Severity.ERROR:
				VNEngineLog.warn("StoryRunner", "  " + diag.format())

	if not script_res.diagnostics.is_empty():
		parse_diagnostics_ready.emit.call_deferred(script_res.diagnostics)

	if script_res.nodes.is_empty():
		VNEngineLog.error("StoryRunner", "Failed to start story: file is empty or unreadable -> %s" % file_path)
		return false

	state.current_file = file_path
	_consecutive_logic_count = 0
	_ended = false
	end_reason = EndReason.SCRIPT_EXHAUSTED
	end_ending_id = ""
	return true

func _process(delta: float) -> void:
	_playtime_accum += delta
	if _playtime_accum >= 1.0:
		var whole: int = int(_playtime_accum)
		state.playtime_sec += whole
		_playtime_accum -= float(whole)

func play_node(index: int) -> void:
	if index < 0 or index >= script_res.nodes.size():
		if index != current_index + 1:
			VNEngineLog.warn("StoryRunner", "Target not found: node %d does not exist (from node: %d)" % [index, current_index])
		end_story(EndReason.SCRIPT_EXHAUSTED)
		return

	current_index = index
	pending_choice_timer = {}
	var node: VNEngineStoryNode = script_res.nodes[index]

	state.current_node_id = node.id

	var is_seen: bool = VNEngineMain.save_data().is_line_seen(script_res.chapter_id, node.line_id)

	if is_skip and not is_seen and not VNEngineMain.settings().skip_unread:
		is_skip = false
		mode_changed.emit()

	VNEngineMain.save_data().mark_line_seen(script_res.chapter_id, node.line_id)

	for entry in node.commands:
		var cname: String = entry.get("name", "")
		if DEFERRED_COMMANDS.has(cname):
			continue
		bus.apply(cname, entry.get("args", ""), ctx)

	if bus.has_pending_block():
		await bus.blocked_finished

	if node.is_pure_logic():
		_consecutive_logic_count += 1
		if _consecutive_logic_count > 256:
			VNEngineLog.error("StoryRunner", "Runaway guard: 256 consecutive logic nodes, possible infinite loop")
			end_story(EndReason.RUNAWAY_GUARD)
			return
		next_node.call_deferred()
		return

	_consecutive_logic_count = 0

	if node.speaker_id != "":
		state.last_speaker = node.speaker_id

	state.history.append({
		"file": state.current_file,
		"node_id": state.current_node_id,
		"speaker": node.speaker_id,
		"text": node.text,
		"line_id": node.line_id,
	})
	if state.history.size() > VNEngineStoryState.MAX_HISTORY:
		state.history.pop_front()
		history_stack.shift_history(-1)

	history_stack.push(state.to_dict(false), state.history.size())

	dialog_started.emit(node)

	if not node.choices.is_empty():
		choices_requested.emit(node.choices)

func next_node() -> void:
	if current_index < 0 or current_index >= script_res.nodes.size():
		return

	var current_node: VNEngineStoryNode = script_res.nodes[current_index]

	if not current_node.choices.is_empty():
		return

	_jumped = false
	for entry in current_node.commands:
		var cname: String = entry.get("name", "")
		if DEFERRED_COMMANDS.has(cname):
			bus.apply(cname, entry.get("args", ""), ctx)
			if _jumped:
				return

	if current_node.next_index != -1:
		play_node(current_node.next_index)
	else:
		end_story(EndReason.SCRIPT_EXHAUSTED)

func make_choice(target_index: int) -> void:
	play_node(target_index)

func get_current_node() -> VNEngineStoryNode:
	if script_res == null or current_index < 0 or current_index >= script_res.nodes.size():
		return null
	return script_res.nodes[current_index]

func execute_load_game(slot_id: int = 0) -> void:
	var loaded_data: Variant = VNEngineMain.saves().load_game(slot_id)

	if loaded_data != null:
		state.from_dict(loaded_data)
		_ended = false
		end_reason = EndReason.SCRIPT_EXHAUSTED
		end_ending_id = ""

		history_stack.clear()

		var file_to_load: String = state.current_file

		pending_choice_timer = {}
		state_restored.emit(state)

		if not _load_script(file_to_load):
			return

		var start_index: int = script_res.index_of(state.current_node_id)
		if start_index == -1:
			VNEngineLog.warn("StoryRunner", "Saved node not found (id: %s), starting from the beginning -> %s" % [state.current_node_id, file_to_load])
			start_index = 0

		current_index = start_index
		var node: VNEngineStoryNode = script_res.nodes[current_index]
		VNEngineMain.save_data().mark_line_seen(script_res.chapter_id, node.line_id)

		dialog_started.emit(node)
		if not node.choices.is_empty():
			choices_requested.emit(node.choices)
	else:
		VNEngineLog.warn("StoryRunner", "No valid save file found in slot: %d" % slot_id)

func rollback() -> void:
	if is_input_locked or bus.has_pending_block() or not history_stack.can_rollback():
		return
	_apply_history_entry(history_stack.rollback())

func forward() -> void:
	if is_input_locked or bus.has_pending_block() or not history_stack.can_forward():
		return
	_apply_history_entry(history_stack.forward())

func _apply_history_entry(entry: Dictionary) -> void:
	var snapshot: Dictionary = entry.get("snapshot", {})
	var target_history_len: int = entry.get("history_len", state.history.size())

	state.from_dict(snapshot)

	if target_history_len < state.history.size():
		state.history.resize(target_history_len)

	pending_choice_timer = {}
	state_restored.emit(state)
	_ended = false
	end_reason = EndReason.SCRIPT_EXHAUSTED
	end_ending_id = ""

	if state.current_file != script_res.source_path:
		if not _load_script(state.current_file):
			return

	current_index = script_res.index_of(state.current_node_id)
	if current_index == -1:
		VNEngineLog.warn("StoryRunner", "HistoryStack entry not found (id: %s) -> %s" % [state.current_node_id, state.current_file])
		return

	var node: VNEngineStoryNode = script_res.nodes[current_index]

	if target_history_len > state.history.size():
		state.history.append({
			"file": state.current_file,
			"node_id": state.current_node_id,
			"speaker": node.speaker_id,
			"text": node.text,
			"line_id": node.line_id,
		})

	dialog_started.emit(node)

	if not node.choices.is_empty():
		choices_requested.emit(node.choices)
