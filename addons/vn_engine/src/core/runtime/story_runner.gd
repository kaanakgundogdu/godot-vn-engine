extends Node
class_name VNEngineStoryRunner


signal dialog_started(node: VNEngineStoryNode)
signal choices_requested(choices: Array[VNEngineChoiceOption])
signal story_ended()
signal state_restored(state: VNEngineStoryState)
signal text_mode_changed(mode: String)
signal nvl_page_cleared

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

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _jumped: bool = false

var _advancing: bool = false

var _consecutive_logic_count: int = 0

var is_auto: bool = false
var is_skip: bool = false
var is_input_locked: bool = false

var line_seen_before: bool = false
var is_restoring: bool = false

var pending_choice_timer: Dictionary = {}

var current_choices: Array[VNEngineChoiceOption] = []
var current_text: String = ""

var _line_paged: bool = false

const RUNAWAY_LIMIT := 256

const DEFERRED_COMMANDS := ["jump", "jump_if", "call", "return", "scene", "end", "goto_chapter", "credits"]

func _init() -> void:
	ctx = VNEngineCommandContext.new()
	bus = VNEngineCommandBus.new()
	ctx.runner = self
	ctx.bus = bus
	ctx.animations = VNEngineAnimationRegistry.new()
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
	_ensure_rng_seeded()
	history_stack.clear()
	clear_nvl_page()
	play_node(start_index)

func _load_script(file_path: String) -> bool:
	script_res = VNEngineMain.game().take_preparsed_script(file_path)
	if script_res == null:
		script_res = VNEngineScenarioLoader.load_script(file_path, flag_list)
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

func _ensure_rng_seeded() -> void:
	if state.rng_seed == 0 and state.rng_state == 0:
		state.seed_rng(randi())

func evaluate_assignment(expr: String) -> Variant:
	_ensure_rng_seeded()
	_rng.seed = state.rng_seed
	_rng.state = state.rng_state
	var value: Variant = VNEngineExpressionEvaluator.evaluate_assignment(expr, state.flags, _rng)
	state.rng_state = _rng.state
	return value

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
	_advancing = false
	_line_paged = false
	pending_choice_timer = {}
	var node: VNEngineStoryNode = script_res.nodes[index]
	current_choices.assign(node.choices)
	is_restoring = false
	line_seen_before = false

	state.current_node_id = node.id

	if not node.is_pure_logic():
		var is_seen: bool = VNEngineMain.save_data().is_line_seen(script_res.chapter_id, node.line_id)
		line_seen_before = is_seen

		if is_skip and not is_seen and not VNEngineMain.settings().skip_unread:
			is_skip = false
			mode_changed.emit()

		VNEngineMain.save_data().mark_line_seen(script_res.chapter_id, node.line_id)

	for entry in node.commands:
		var cname: String = entry.get("name", "")
		if DEFERRED_COMMANDS.has(cname) or entry.get("after_line", false):
			continue
		bus.apply(cname, entry.get("args", ""), ctx)

	if bus.has_pending_block():
		await bus.blocked_finished

	current_choices = _visible_choices(node)
	current_text = VNEngineTextMarkup.interpolate(node.text, state.flags)

	if node.text == "" and current_choices.is_empty():
		_consecutive_logic_count += 1
		if _consecutive_logic_count > RUNAWAY_LIMIT:
			_trip_runaway_guard(node)
			return
		next_node.call_deferred()
		return

	_consecutive_logic_count = 0

	if node.expression != "" and ctx.characters != null and state.characters.has(node.speaker_id):
		var shown: Variant = state.characters[node.speaker_id]
		if typeof(shown) == TYPE_DICTIONARY:
			ctx.characters.show_character(node.speaker_id, shown.get("outfit", ""), shown.get("pose", ""), node.expression, shown.get("shot", ""), "", "")
			shown["expression"] = node.expression

	if node.animation != "":
		ctx.animations.play_on_character(node.speaker_id, node.animation, node.animation_params, ctx)

	if node.speaker_id != "":
		state.last_speaker = node.speaker_id

	state.history.append({
		"file": state.current_file,
		"node_id": state.current_node_id,
		"speaker": node.speaker_id,
		"text": VNEngineTextMarkup.strip(current_text),
		"line_id": node.line_id,
	})
	if state.history.size() > VNEngineStoryState.MAX_HISTORY:
		state.history.pop_front()
		history_stack.shift_history(-1)

	history_stack.push(state.to_dict(false), state.history.size())

	dialog_started.emit(node)

	if not current_choices.is_empty():
		choices_requested.emit(current_choices)

func choice_key(choice: VNEngineChoiceOption) -> String:
	return "%s:%d" % [state.current_file, choice.line]

func _visible_choices(node: VNEngineStoryNode) -> Array[VNEngineChoiceOption]:
	var result: Array[VNEngineChoiceOption] = []
	for choice in node.choices:
		if choice.once and state.seen_choices.has(choice_key(choice)):
			continue
		if choice.condition != "" and not VNEngineExpressionEvaluator.evaluate(choice.condition, state.flags):
			continue
		result.append(choice)
	return result

func _trip_runaway_guard(node: VNEngineStoryNode) -> void:
	if _ended:
		return
	_ended = true
	end_reason = EndReason.RUNAWAY_GUARD
	end_ending_id = ""
	var message: String = "Runaway guard: %d consecutive logic nodes at '%s', possible infinite loop" % [RUNAWAY_LIMIT, node.id]
	if OS.is_debug_build():
		var diagnostic: VNEngineParseDiagnostic = VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.ERROR, node.line, message, "check jump/jump_if targets in '%s'" % state.current_file.get_file())
		parse_diagnostics_ready.emit([diagnostic])
		return
	push_error("StoryRunner: %s (%s)" % [message, state.current_file])
	parse_diagnostics_ready.emit([VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.ERROR, node.line, message)])

func _run_after_line_commands(node: VNEngineStoryNode) -> void:
	for entry in node.commands:
		var cname: String = entry.get("name", "")
		if DEFERRED_COMMANDS.has(cname) or not entry.get("after_line", false):
			continue
		bus.apply(cname, entry.get("args", ""), ctx)

	if bus.has_pending_block():
		await bus.blocked_finished

func next_node() -> void:
	if _advancing:
		return
	if current_index < 0 or current_index >= script_res.nodes.size():
		return

	var current_node: VNEngineStoryNode = script_res.nodes[current_index]

	if not current_choices.is_empty():
		return

	_advancing = true
	_page_current_line()
	await _run_after_line_commands(current_node)
	if not _advancing:
		return
	_advancing = false

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
	if _advancing:
		return
	var current_node: VNEngineStoryNode = get_current_node()
	if current_node != null:
		_advancing = true
		_page_current_line()
		await _run_after_line_commands(current_node)
		if not _advancing:
			return
		_advancing = false
	play_node(target_index)

func effective_text_mode() -> String:
	if state.text_mode != "":
		return state.text_mode
	var manifest: VNEngineGameManifest = VNEngineMain.game().get_manifest()
	return manifest.text_mode if manifest != null else "adv"

func is_nvl() -> bool:
	return effective_text_mode() == "nvl"

func set_text_mode(mode: String) -> void:
	if mode == effective_text_mode():
		return
	state.text_mode = mode
	clear_nvl_page()
	text_mode_changed.emit(mode)

func clear_nvl_page() -> void:
	state.nvl_page.clear()
	nvl_page_cleared.emit()

func add_nvl_choice(text: String) -> void:
	if not is_nvl():
		return
	_page_current_line()
	state.nvl_page.append({"speaker": "", "text": text, "kind": "choice"})

func _page_current_line() -> void:
	if _line_paged:
		return
	_line_paged = true
	var node: VNEngineStoryNode = get_current_node()
	if node == null or not is_nvl():
		return
	var text: String = VNEngineTextMarkup.strip(current_text)
	if text == "":
		return
	state.nvl_page.append({"speaker": node.speaker_id, "text": text, "kind": "line"})

func get_current_node() -> VNEngineStoryNode:
	if script_res == null or current_index < 0 or current_index >= script_res.nodes.size():
		return null
	return script_res.nodes[current_index]

func execute_load_game(slot_id: int = 0) -> void:
	var loaded_data: Variant = VNEngineMain.saves().load_game(slot_id)

	if loaded_data != null:
		state.from_dict(loaded_data)
		_advancing = false
		_ended = false
		end_reason = EndReason.SCRIPT_EXHAUSTED
		end_ending_id = ""

		history_stack.clear()
		_line_paged = false

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

		current_choices = _visible_choices(node)
		current_text = VNEngineTextMarkup.interpolate(node.text, state.flags)
		line_seen_before = true
		dialog_started.emit(node)
		if not current_choices.is_empty():
			is_restoring = true
			choices_requested.emit(current_choices)
			is_restoring = false
	else:
		VNEngineLog.warn("StoryRunner", "No valid save file found in slot: %d" % slot_id)

func start_from_snapshot(data: Dictionary) -> void:
	state.from_dict(data)
	_advancing = false
	_ended = false
	end_reason = EndReason.SCRIPT_EXHAUSTED
	end_ending_id = ""
	history_stack.clear()
	_line_paged = false
	pending_choice_timer = {}
	state_restored.emit(state)

	if not _load_script(state.current_file):
		return

	var start_index: int = script_res.index_of(state.current_node_id)
	if start_index == -1:
		VNEngineLog.warn("StoryRunner", "Flow node not found (id: %s), starting from the beginning -> %s" % [state.current_node_id, state.current_file])
		start_index = 0
	play_node(start_index)

func reach_flow_box(box_id: String) -> void:
	var save_data: VNEngineSaveData = VNEngineMain.save_data()
	var snapshot: Dictionary = state.to_dict(false)
	for i in range(state.history.size() - 1, -1, -1):
		if String(state.history[i].get("text", "")) != "":
			snapshot["history"] = [state.history[i].duplicate(true)]
			break
	save_data.write_flow_snapshot(box_id, snapshot)
	save_data.mark_flow_reached(box_id)
	if state.flow_path.is_empty() or state.flow_path.back() != box_id:
		state.flow_path.append(box_id)

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
	_advancing = false
	_line_paged = false

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
	current_text = VNEngineTextMarkup.interpolate(node.text, state.flags)

	if target_history_len > state.history.size():
		state.history.append({
			"file": state.current_file,
			"node_id": state.current_node_id,
			"speaker": node.speaker_id,
			"text": VNEngineTextMarkup.strip(current_text),
			"line_id": node.line_id,
		})

	current_choices = _visible_choices(node)
	line_seen_before = true
	dialog_started.emit(node)

	if not current_choices.is_empty():
		is_restoring = true
		choices_requested.emit(current_choices)
		is_restoring = false
