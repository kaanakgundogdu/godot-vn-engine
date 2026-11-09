class_name VNEngineOverlayStack
extends RefCounted
const _SETTINGS_SCENE: PackedScene = preload("res://addons/vn_engine/src/ui/scenes/settings_panel.tscn")
const _LOAD_SCENE: PackedScene = preload("res://addons/vn_engine/src/ui/scenes/load_panel.tscn")
const _GALLERY_SCENE: PackedScene = preload("res://addons/vn_engine/src/ui/scenes/gallery_panel.tscn")
const _LOG_SCENE: PackedScene = preload("res://addons/vn_engine/src/ui/scenes/log_ui.tscn")
const _CONFIRM_SCENE: PackedScene = preload("res://addons/vn_engine/src/ui/scenes/confirm_dialog.tscn")
const _GAME_MENU_SCENE: PackedScene = preload("res://addons/vn_engine/src/ui/scenes/game_menu.tscn")
const _FLOWCHART_SCENE: PackedScene = preload("res://addons/vn_engine/src/ui/scenes/flowchart_panel.tscn")

const BUILTIN_OVERLAYS: Dictionary = {
	&"settings": _SETTINGS_SCENE,
	&"load": _LOAD_SCENE,
	&"gallery": _GALLERY_SCENE,
	&"log": _LOG_SCENE,
	&"confirm": _CONFIRM_SCENE,
	&"game_menu": _GAME_MENU_SCENE,
	&"flowchart": _FLOWCHART_SCENE,
}

var _layer: CanvasLayer
var _screen_stack: VNEngineScreenStack
var _overrides: Dictionary = {}
var _theme: Theme = null
const OPEN_TIME: float = 0.18
const CLOSE_TIME: float = 0.12
const START_SCALE: float = 0.97
const PROGRESS: StringName = &"overlay_progress"
const TWEEN: StringName = &"overlay_tween"
const BACKDROP: StringName = &"overlay_backdrop"
const BACKDROP_ALPHA: StringName = &"overlay_backdrop_alpha"

var _stack: Array[Control] = []
var _fading: Array[Control] = []


func _init(layer: CanvasLayer, screen_stack: VNEngineScreenStack, overrides: Dictionary = {}, theme: Theme = null) -> void:
	_layer = layer
	_screen_stack = screen_stack
	_overrides = overrides
	_theme = theme


func scene_for(id: StringName) -> PackedScene:
	var custom: PackedScene = _overrides.get(id) as PackedScene
	if custom != null:
		return custom
	return BUILTIN_OVERLAYS.get(id, null) as PackedScene


func is_empty() -> bool:
	return _stack.is_empty()


func top_overlay() -> Control:
	if _stack.is_empty():
		return null
	return _stack.back()


func open_overlay(id: StringName, params: Dictionary = {}) -> Control:
	var scene: PackedScene = scene_for(id)
	if scene == null:
		VNEngineLog.warn("OverlayStack", "Unknown overlay id: '%s'" % id)
		return null

	var current: VNEngineScreen = _screen_stack.current_screen()
	if current != null and not current.allows_overlay(id):
		VNEngineLog.warn("OverlayStack", "Overlay '%s' not allowed on screen '%s'" % [id, current.screen_id()])
		return null

	if _stack.is_empty():
		if current != null:
			current.on_blur()
	else:
		var below: Control = _stack.back()
		_finish(below)
		below.mouse_filter = Control.MOUSE_FILTER_IGNORE
		below.hide()

	var overlay: Control = scene.instantiate() as Control

	if _theme != null and overlay.theme == null:
		overlay.theme = _theme

	_layer.add_child(overlay)

	var backdrop_alpha: float = 1.0
	if overlay is ColorRect:
		var manifest: VNEngineGameManifest = VNEngineMain.game().get_manifest()
		var ui_def: VNEngineUiDef = manifest.get_ui() if manifest != null else VNEngineUiDef.new()
		(overlay as ColorRect).color = ui_def.overlay_backdrop_color
		backdrop_alpha = ui_def.overlay_backdrop_color.a

	var animated: bool = VNEngineUiMotion.enabled() and VNEngineUiMotion.time(OPEN_TIME) > 0.0
	if animated:
		var takeover: bool = not _stack.is_empty() or not _fading.is_empty()
		overlay.set_meta(BACKDROP_ALPHA, backdrop_alpha)
		overlay.set_meta(BACKDROP, 1.0 if takeover else -1.0)
		for fading: Control in _fading:
			fading.set_meta(BACKDROP, 0.0)
			_apply(fading.get_meta(PROGRESS), fading)
		_apply(0.0, overlay)

	if params.has("asset_resolver") and overlay.has_method("set_asset_resolver"):
		overlay.set_asset_resolver(params.asset_resolver)

	if params.has("runner") and overlay.has_method("set_runner"):
		overlay.set_runner(params.runner)

	if overlay.has_method("configure"):
		overlay.configure(params)

	if overlay.has_method("open_panel"):
		if params.has("save_mode"):
			overlay.open_panel(params.save_mode)
		else:
			overlay.open_panel()

	if overlay.has_signal("closed"):
		overlay.closed.connect(close_overlay)

	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_stack.push_back(overlay)
	if animated:
		_run(overlay, 1.0, OPEN_TIME, Callable())
	return overlay


func close_all() -> void:
	while not _stack.is_empty():
		close_overlay(true)
	while not _fading.is_empty():
		_discard(_fading.back())


func close_overlay(instant: bool = false) -> void:
	if _stack.is_empty():
		return

	var top: Control = _stack.pop_back()
	var emptied: bool = _stack.is_empty()
	if instant or not VNEngineUiMotion.enabled() or VNEngineUiMotion.time(CLOSE_TIME) <= 0.0:
		_discard(top)
	else:
		_fade_out(top, emptied)

	if _stack.is_empty():
		var current: VNEngineScreen = _screen_stack.current_screen()
		if current != null:
			current.on_focus()
	else:
		var new_top: Control = _stack.back()
		new_top.mouse_filter = Control.MOUSE_FILTER_STOP
		new_top.show()


func _fade_out(overlay: Control, with_backdrop: bool) -> void:
	var focused: Control = overlay.get_viewport().gui_get_focus_owner()
	if focused != null and overlay.is_ancestor_of(focused):
		focused.release_focus()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.process_mode = Node.PROCESS_MODE_DISABLED
	if not overlay.has_meta(PROGRESS):
		overlay.set_meta(PROGRESS, 1.0)
	overlay.set_meta(BACKDROP, -1.0 if with_backdrop else 0.0)
	_fading.append(overlay)
	_run(overlay, 0.0, CLOSE_TIME, _discard.bind(overlay))


func _run(overlay: Control, target: float, base_time: float, done: Callable) -> void:
	_kill(overlay)
	var tween: Tween = _layer.create_tween()
	tween.tween_method(_apply.bind(overlay), float(overlay.get_meta(PROGRESS)), target, VNEngineUiMotion.time(base_time)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if done.is_valid():
		tween.finished.connect(done)
	overlay.set_meta(TWEEN, tween)


func _kill(overlay: Control) -> void:
	if not overlay.has_meta(TWEEN):
		return
	var tween: Tween = overlay.get_meta(TWEEN)
	if tween.is_valid():
		tween.kill()
	overlay.remove_meta(TWEEN)


func _finish(overlay: Control) -> void:
	if not overlay.has_meta(TWEEN):
		return
	var tween: Tween = overlay.get_meta(TWEEN)
	if tween.is_valid():
		tween.custom_step(99.0)


func _discard(overlay: Control) -> void:
	_kill(overlay)
	_fading.erase(overlay)
	_layer.remove_child(overlay)
	overlay.queue_free()


func _apply(progress: float, overlay: Control) -> void:
	overlay.set_meta(PROGRESS, progress)
	var rect: ColorRect = overlay as ColorRect
	if rect == null:
		overlay.modulate.a = progress
		return
	var backdrop: float = overlay.get_meta(BACKDROP, 1.0)
	rect.color.a = float(overlay.get_meta(BACKDROP_ALPHA, rect.color.a)) * (progress if backdrop < 0.0 else backdrop)
	var scaled: bool = not VNEngineUiMotion.reduced()
	for child: Node in overlay.get_children():
		var item: Control = child as Control
		if item == null:
			continue
		item.modulate.a = progress
		if scaled:
			item.pivot_offset = item.size / 2.0
			item.scale = Vector2.ONE * lerpf(START_SCALE, 1.0, progress)
