class_name VNEngineOverlayStack
extends RefCounted
const _SETTINGS_SCENE: PackedScene = preload("res://addons/vn_engine/src/ui/scenes/settings_panel.tscn")
const _LOAD_SCENE: PackedScene = preload("res://addons/vn_engine/src/ui/scenes/load_panel.tscn")
const _GALLERY_SCENE: PackedScene = preload("res://addons/vn_engine/src/ui/scenes/gallery_panel.tscn")
const _LOG_SCENE: PackedScene = preload("res://addons/vn_engine/src/ui/scenes/log_ui.tscn")
const _CONFIRM_SCENE: PackedScene = preload("res://addons/vn_engine/src/ui/scenes/confirm_dialog.tscn")
const _GAME_MENU_SCENE: PackedScene = preload("res://addons/vn_engine/src/ui/scenes/game_menu.tscn")

const BUILTIN_OVERLAYS: Dictionary = {
	&"settings": _SETTINGS_SCENE,
	&"load": _LOAD_SCENE,
	&"gallery": _GALLERY_SCENE,
	&"log": _LOG_SCENE,
	&"confirm": _CONFIRM_SCENE,
	&"game_menu": _GAME_MENU_SCENE,
}

var _layer: CanvasLayer
var _screen_stack: VNEngineScreenStack
var _overrides: Dictionary = {}
var _theme: Theme = null
var _stack: Array[Control] = []


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
		below.mouse_filter = Control.MOUSE_FILTER_IGNORE
		below.hide()

	var overlay: Control = scene.instantiate() as Control

	if _theme != null and overlay.theme == null:
		overlay.theme = _theme

	_layer.add_child(overlay)

	if overlay is ColorRect:
		var manifest: VNEngineGameManifest = VNEngineMain.game().get_manifest()
		var ui_def: VNEngineUiDef = manifest.get_ui() if manifest != null else VNEngineUiDef.new()
		(overlay as ColorRect).color = ui_def.overlay_backdrop_color

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
	return overlay


func close_all() -> void:
	while not _stack.is_empty():
		close_overlay()


func close_overlay() -> void:
	if _stack.is_empty():
		return

	var top: Control = _stack.pop_back()
	_layer.remove_child(top)
	top.queue_free()

	if _stack.is_empty():
		var current: VNEngineScreen = _screen_stack.current_screen()
		if current != null:
			current.on_focus()
	else:
		var new_top: Control = _stack.back()
		new_top.mouse_filter = Control.MOUSE_FILTER_STOP
		new_top.show()
