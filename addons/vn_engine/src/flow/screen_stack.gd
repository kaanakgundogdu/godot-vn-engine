class_name VNEngineScreenStack
extends RefCounted

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

var _layer: CanvasLayer
var _overrides: Dictionary = {}
var _theme: Theme = null
var _current: VNEngineScreen = null
var _current_id: StringName = &""
var _current_params: Dictionary = {}
var _stack: Array[Dictionary] = []


func _init(layer: CanvasLayer, overrides: Dictionary = {}, theme: Theme = null) -> void:
	_layer = layer
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


func push_screen(id: StringName, params: Dictionary = {}) -> VNEngineScreen:
	if _current_id != &"":
		_stack.push_back({"id": _current_id, "params": _current_params})
	return _swap_to(id, params)


func replace_screen(id: StringName, params: Dictionary = {}) -> VNEngineScreen:
	return _swap_to(id, params)


func pop_screen() -> VNEngineScreen:
	if _stack.is_empty():
		return _current
	var prev: Dictionary = _stack.pop_back()
	return _swap_to(prev.id, prev.params)


func clear_stack() -> void:
	_stack.clear()


func _swap_to(id: StringName, params: Dictionary) -> VNEngineScreen:
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

	if _current != null:
		_current.exit()
		_layer.remove_child(_current)
		_current.queue_free()

	if _theme != null and screen.theme == null:
		screen.theme = _theme

	_layer.add_child(screen)
	_current = screen
	_current_id = id
	_current_params = params
	screen.enter(params)
	screen.on_focus()
	return screen
