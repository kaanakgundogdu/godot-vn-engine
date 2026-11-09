class_name VNEngineScreenStack
extends RefCounted

signal transition_finished
signal _woken

const _TITLE_SCENE: PackedScene = preload("res://addons/vn_engine/src/screens/scenes/title_screen.tscn")
const _STAGE_SCENE: PackedScene = preload("res://addons/vn_engine/src/screens/scenes/vn_stage_screen.tscn")
const _OPENING_SCENE: PackedScene = preload("res://addons/vn_engine/src/screens/scenes/opening_screen.tscn")
const _CREDITS_SCENE: PackedScene = preload("res://addons/vn_engine/src/screens/scenes/credits_screen.tscn")
const _EXTRAS_SCENE: PackedScene = preload("res://addons/vn_engine/src/screens/scenes/extras_screen.tscn")
const _CHAPTER_SELECT_SCENE: PackedScene = preload("res://addons/vn_engine/src/screens/scenes/chapter_select_screen.tscn")
const _LOADING_SCENE: PackedScene = preload("res://addons/vn_engine/src/screens/scenes/loading_screen.tscn")

const DIAGNOSTICS_SCENE_PATH := "res://addons/vn_engine/src/screens/scenes/diagnostics_screen.tscn"

const BUILTIN_SCREENS: Dictionary = {
	&"title": _TITLE_SCENE,
	&"stage": _STAGE_SCENE,
	&"opening": _OPENING_SCENE,
	&"credits": _CREDITS_SCENE,
	&"extras": _EXTRAS_SCENE,
	&"chapter_select": _CHAPTER_SELECT_SCENE,
	&"loading": _LOADING_SCENE,
}

var before_swap: Callable = Callable()

var _layer: CanvasLayer
var _fader: VNEngineScreenFader
var _overrides: Dictionary = {}
var _theme: Theme = null
var _current: VNEngineScreen = null
var _current_id: StringName = &""
var _logical_id: StringName = &""
var _logical_params: Dictionary = {}
var _stack: Array[Dictionary] = []
var _busy: bool = false
var _pending: Dictionary = {}
var _shown: bool = false
var _warned_kinds: Dictionary = {}


func _init(layer: CanvasLayer, fader: VNEngineScreenFader, overrides: Dictionary = {}, theme: Theme = null) -> void:
	_layer = layer
	_fader = fader
	_overrides = overrides
	_theme = theme


func has_screen(id: StringName) -> bool:
	if id == &"diagnostics":
		return _overrides.has(id) or ResourceLoader.exists(DIAGNOSTICS_SCENE_PATH)
	return _overrides.has(id) or BUILTIN_SCREENS.has(id)


func scene_path(id: StringName) -> String:
	var custom: PackedScene = _overrides.get(id) as PackedScene
	if custom != null:
		return custom.resource_path
	if id == &"diagnostics":
		return DIAGNOSTICS_SCENE_PATH
	var scene: PackedScene = BUILTIN_SCREENS.get(id, null) as PackedScene
	return scene.resource_path if scene != null else ""


func current_screen() -> VNEngineScreen:
	return _current


func current_id() -> StringName:
	return _current_id


func is_transitioning() -> bool:
	return _busy


func push_screen(id: StringName, params: Dictionary = {}, transition: Dictionary = {}) -> void:
	if _logical_id != &"":
		_stack.push_back({"id": _logical_id, "params": _logical_params})
	_request(id, params, transition)


func replace_screen(id: StringName, params: Dictionary = {}, transition: Dictionary = {}) -> void:
	_request(id, params, transition)


func pop_screen(transition: Dictionary = {}) -> void:
	if _stack.is_empty():
		return
	var prev: Dictionary = _stack.pop_back()
	_request(prev.id, prev.params, transition)


func clear_stack() -> void:
	_stack.clear()


func show_pending() -> void:
	_shown = true
	_woken.emit()


func run_covered(key: StringName, action: Callable) -> void:
	var resolved: Dictionary = _resolve(key, {}, {}, false)
	if _busy or resolved.kind == "instant":
		action.call()
		return
	var kind: String = "fade" if VNEngineScreenFader.is_slide(resolved.kind) else resolved.kind
	_busy = true
	_lock(true)
	await _fader.cover(kind, resolved.time * 0.5)
	action.call()
	await _fader.reveal(kind, resolved.time * 0.5)
	_finish()


func cover(transition: Dictionary) -> void:
	var resolved: Dictionary = _resolve(&"", {}, transition, false)
	if _busy or resolved.kind == "instant":
		return
	var kind: String = "fade" if VNEngineScreenFader.is_slide(resolved.kind) else resolved.kind
	_busy = true
	_lock(true)
	if _current != null:
		_current.process_mode = Node.PROCESS_MODE_DISABLED
	await _fader.cover(kind, resolved.time * 0.5)


func uncover() -> void:
	if not _busy or not _fader.is_covered():
		return
	_fader.clear()
	_finish()


func _request(id: StringName, params: Dictionary, transition: Dictionary) -> void:
	_logical_id = id
	_logical_params = params
	var resolved: Dictionary = _resolve(id, params, transition, true)
	var request: Dictionary = {"id": id, "params": params, "kind": resolved.kind, "time": resolved.time}
	if _busy:
		_pending = request
		_woken.emit()
		return
	if resolved.kind == "instant" or (_current == null and id == &"opening"):
		_swap(request)
		return
	_pending = request
	_run()


func _resolve(id: StringName, params: Dictionary, transition: Dictionary, allow_reverse: bool) -> Dictionary:
	var ui: VNEngineUiDef = VNEngineMain.game().get_ui()
	var key: StringName = StringName(params.get("next_screen", id)) if id == &"loading" else id
	var kind: String = String(transition.get("kind", ""))
	var time: float = float(transition.get("time", -1.0))
	if kind == "":
		if ui.screen_transitions.has(key):
			kind = ui.screen_transitions[key]
		elif allow_reverse and ui.screen_transitions.has(_current_id):
			kind = VNEngineScreenFader.reversed(ui.screen_transitions[_current_id])
		else:
			kind = ui.screen_transition
	if time < 0.0:
		time = ui.screen_transition_time * ui.ui_animation_scale
	if not VNEngineScreenFader.KINDS.has(kind):
		if not _warned_kinds.has(kind):
			_warned_kinds[kind] = true
			VNEngineLog.warn("ScreenStack", "Unknown screen transition '%s', using fade" % kind)
		kind = "fade"
	if id == &"diagnostics" or time <= 0.0 or _card_held() or not _fader.is_inside_tree():
		kind = "instant"
	elif kind != "instant" and VNEngineMain.settings() != null and VNEngineMain.settings().reduce_motion:
		kind = "fade"
		time *= 0.5
	return {"kind": kind, "time": time}


func _card_held() -> bool:
	var root: VNEngineMain = VNEngineMain.instance()
	return root != null and root.get_card_overlay() != null and root.get_card_overlay().is_held()


func _run() -> void:
	_busy = true
	_lock(true)
	var kind: String = _pending.kind
	var reveal_only: bool = _current == null or _current_id == &"opening"
	if _current != null:
		_current.process_mode = Node.PROCESS_MODE_DISABLED
	if VNEngineScreenFader.is_slide(kind) and not reveal_only:
		await _slide_chain()
	else:
		if reveal_only:
			await _fader.cover("fade", 0.0)
		else:
			await _fader.cover(kind, _pending.time * 0.5)
		var last: Dictionary = await _swap_chain()
		var reveal_kind: String = last.kind
		if reveal_only or reveal_kind == "instant" or VNEngineScreenFader.is_slide(reveal_kind):
			reveal_kind = "fade"
		await _fader.reveal(reveal_kind, last.time * 0.5)
	_finish()


func _finish() -> void:
	_busy = false
	_lock(false)
	if _current != null:
		_current.process_mode = Node.PROCESS_MODE_INHERIT
	transition_finished.emit()
	if _pending.is_empty():
		return
	if _pending.kind == "instant":
		var request: Dictionary = _pending
		_pending = {}
		_swap(request)
		return
	_run()


func _swap_chain() -> Dictionary:
	var request: Dictionary = {}
	while true:
		request = _pending
		_pending = {}
		_shown = false
		if not _swap(request):
			break
		if _current.holds_transition() and not _shown:
			await _woken
			if not _pending.is_empty():
				continue
		break
	return request


func _slide_chain() -> void:
	var old: VNEngineScreen = _current
	var request: Dictionary = {}
	var incoming: VNEngineScreen = null
	old.exit()
	while true:
		request = _pending
		_pending = {}
		_shown = false
		if incoming != null:
			incoming.exit()
			_layer.remove_child(incoming)
			incoming.queue_free()
		incoming = _instantiate(request.id)
		if incoming == null:
			break
		if before_swap.is_valid():
			before_swap.call()
		incoming.visible = false
		_enter(incoming, request)
		if incoming.holds_transition() and not _shown:
			await _woken
			if not _pending.is_empty():
				continue
		break
	if incoming == null:
		_layer.remove_child(old)
		old.queue_free()
		if _current == old:
			_current = null
			_current_id = &""
		return
	var offset: Vector2 = _slide_offset(request.kind, old.size)
	incoming.position = -offset
	incoming.visible = true
	var tween: Tween = _fader.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(old, "position", offset, request.time)
	tween.tween_property(incoming, "position", Vector2.ZERO, request.time)
	await tween.finished
	_layer.remove_child(old)
	old.queue_free()


func _slide_offset(kind: String, size: Vector2) -> Vector2:
	match kind:
		"slide_left":
			return Vector2(-size.x, 0.0)
		"slide_right":
			return Vector2(size.x, 0.0)
		"slide_up":
			return Vector2(0.0, -size.y)
		_:
			return Vector2(0.0, size.y)


func _swap(request: Dictionary) -> bool:
	var screen: VNEngineScreen = _instantiate(request.id)
	if screen == null:
		return false
	if before_swap.is_valid():
		before_swap.call()
	if _current != null:
		_current.exit()
		_layer.remove_child(_current)
		_current.queue_free()
	_enter(screen, request)
	return true


func _instantiate(id: StringName) -> VNEngineScreen:
	var scene: PackedScene = _overrides.get(id) as PackedScene
	if scene == null and id == &"diagnostics":
		scene = load(DIAGNOSTICS_SCENE_PATH) as PackedScene
	elif scene == null:
		scene = BUILTIN_SCREENS.get(id, null) as PackedScene
	if scene == null:
		VNEngineLog.warn("ScreenStack", "Unknown screen id: '%s'" % id)
		return null

	var node: Node = scene.instantiate()
	var screen: VNEngineScreen = node as VNEngineScreen
	if screen == null:
		node.free()
		VNEngineLog.error("ScreenStack", "Screen '%s' must have a VNScreen root" % id)
		return null
	if _theme != null and screen.theme == null:
		screen.theme = _theme
	return screen


func _enter(screen: VNEngineScreen, request: Dictionary) -> void:
	_layer.add_child(screen)
	_current = screen
	_current_id = request.id
	screen.enter(request.params)
	screen.on_focus()


func _lock(locked: bool) -> void:
	var viewport: Viewport = _layer.get_viewport()
	if viewport == null:
		return
	viewport.gui_disable_input = locked
	if locked:
		viewport.gui_release_focus()
