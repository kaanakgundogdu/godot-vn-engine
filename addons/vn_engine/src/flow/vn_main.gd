class_name VNEngineMain
extends Node

const DEV_OVERLAY_SCENE := "res://addons/vn_engine/src/ui/scenes/dev_overlay.tscn"

@export_dir var content_root: String = ""
@export var save_folder: String = "user://vn_engine/{game_id}/saves/"
@export var settings_file: String = "user://vn_engine/{game_id}/settings.json"
@export var verbose_log: bool = false

@export_group("Display")
## Resolution the engine UI is drawn for. The window is scaled to fit it.
@export var design_resolution: Vector2i = Vector2i(1920, 1080)
## While the engine runs it scales the window to design_resolution and
## restores the old values when it leaves the tree. Turn off if your
## project sets its own stretch settings.
@export var manage_window_scaling: bool = true

var screen_stack: VNEngineScreenStack
var overlay_stack: VNEngineOverlayStack
var dev_overlay: Control = null

@onready var screen_layer: CanvasLayer = $ScreenLayer
@onready var overlay_layer: CanvasLayer = $OverlayLayer
@onready var transition_layer: CanvasLayer = $TransitionLayer
@onready var system_layer: CanvasLayer = $SystemLayer
@onready var systems: Node = $Systems
@onready var persistent_audio: VNEngineAudioSystem = $Systems/PersistentAudio
@onready var _game: VNEngineGame = $Systems/Game
@onready var _saves: VNEngineSaveSystem = $Systems/Saves


const DEFAULT_THEME_PATH := "res://addons/vn_engine/src/themes/vn_default.tres"


static var _current: VNEngineMain = null

var _is_duplicate: bool = false
var _save_data: VNEngineSaveData
var _settings: VNEngineSettings
var _saved_scaling: Dictionary = {}
var _engine_theme: Theme = null


func _enter_tree() -> void:
	if _current != null and is_instance_valid(_current) and _current != self:
		push_warning("Another VNEngineMain is already running, freeing this one.")
		_is_duplicate = true
		queue_free()
		return
	_current = self
	_apply_window_scaling()
	VNEnginePaths.set_content_root(content_root)
	VNEngineLog.verbose = verbose_log


func _exit_tree() -> void:
	if _is_duplicate:
		return
	if _save_data != null:
		_save_data.flush()
	if _settings != null:
		_settings.restore_audio()
	if _current == self:
		_current = null
	_restore_window_scaling()
	if _engine_theme != null and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


# Theme does not pass through CanvasLayer or plain Node parents, so every
# Control that starts a new branch under the engine gets the theme itself.
func _on_node_added(node: Node) -> void:
	if is_ancestor_of(node):
		_theme_control(node)


func _theme_subtree(node: Node) -> void:
	for child in node.get_children():
		_theme_control(child)
		_theme_subtree(child)


func _theme_control(node: Node) -> void:
	var control: Control = node as Control
	if control == null or control.theme != null or control.get_parent() is Control:
		return
	control.theme = _engine_theme


func _apply_window_scaling() -> void:
	if not manage_window_scaling or DisplayServer.get_name() == "headless":
		return
	var window: Window = get_tree().root
	_saved_scaling = {
		"size": window.content_scale_size,
		"mode": window.content_scale_mode,
		"aspect": window.content_scale_aspect,
		"min_size": window.min_size,
	}
	window.content_scale_size = design_resolution
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.min_size = window.min_size.max(design_resolution / 2)


func _restore_window_scaling() -> void:
	if _saved_scaling.is_empty() or not is_inside_tree():
		return
	var window: Window = get_tree().root
	window.content_scale_size = _saved_scaling["size"]
	window.content_scale_mode = _saved_scaling["mode"]
	window.content_scale_aspect = _saved_scaling["aspect"]
	window.min_size = _saved_scaling["min_size"]
	_saved_scaling = {}


func _notification(what: int) -> void:
	if _is_duplicate:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		VNEngineSettings.set_focus_muted(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		VNEngineSettings.set_focus_muted(false)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _save_data != null:
			_save_data.flush()


func _ready() -> void:
	if _is_duplicate:
		return
	if content_root == "":
		push_error("VNEngineMain: content_root is empty. Set it in the Inspector to your game folder (e.g. res://my_game/).")
		return
	if not ResourceLoader.exists(VNEnginePaths.manifest()):
		push_error("VNEngineMain: no game manifest found at '%s'. Check content_root in the Inspector." % VNEnginePaths.manifest())
		return
	if OS.is_debug_build() and ResourceLoader.exists(DEV_OVERLAY_SCENE):
		var dev_overlay_scene: PackedScene = load(DEV_OVERLAY_SCENE)
		dev_overlay = dev_overlay_scene.instantiate()
		dev_overlay.visible = false
		system_layer.add_child(dev_overlay)
	_game.start_engine()
	_save_data = VNEngineSaveData.new(resolve_path(save_folder))
	_settings = VNEngineSettings.load_from(resolve_path(settings_file))
	_settings.apply_all()
	var engine_theme: Theme = null
	if str(ProjectSettings.get_setting("gui/theme/custom", "")) == "":
		engine_theme = load(DEFAULT_THEME_PATH)
		_engine_theme = engine_theme
		_theme_subtree(self)
		get_tree().node_added.connect(_on_node_added)
	var ui: VNEngineUiDef = _game.get_ui()
	screen_stack = VNEngineScreenStack.new(screen_layer, ui.screens, engine_theme)
	overlay_stack = VNEngineOverlayStack.new(overlay_layer, screen_stack, ui.overlays, engine_theme)

	screen_stack.push_screen(_game.start_screen())


func _unhandled_input(event: InputEvent) -> void:
	if _is_duplicate:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		if dev_overlay != null:
			dev_overlay.visible = not dev_overlay.visible
			get_viewport().set_input_as_handled()
		return

	if not event.is_action_pressed(&"ui_cancel"):
		return

	if not overlay_stack.is_empty():
		var top: Control = overlay_stack.top_overlay()
		var consumed: bool = false
		if top != null and top.has_method("handle_back"):
			consumed = top.handle_back()
		if not consumed:
			overlay_stack.close_overlay()
		get_viewport().set_input_as_handled()
		return

	var current: VNEngineScreen = screen_stack.current_screen()
	if current != null:
		current.handle_back()
	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _is_duplicate:
		return
	if not event.is_action_pressed(VNEngineInput.ALT_CLICK):
		return

	if not overlay_stack.is_empty():
		var top: Control = overlay_stack.top_overlay()
		var consumed: bool = false
		if top != null and top.has_method("handle_back"):
			consumed = top.handle_back()
		if not consumed:
			overlay_stack.close_overlay()
		get_viewport().set_input_as_handled()
		return

	var current_screen: VNEngineScreen = screen_stack.current_screen()
	if current_screen != null and current_screen.handle_alt_click():
		get_viewport().set_input_as_handled()


static func instance() -> VNEngineMain:
	return _current


static func saves() -> VNEngineSaveSystem:
	if _current == null:
		return null
	return _current._saves


static func game() -> VNEngineGame:
	if _current == null:
		return null
	return _current._game


static func save_data() -> VNEngineSaveData:
	if _current == null:
		return null
	return _current._save_data


static func settings() -> VNEngineSettings:
	if _current == null:
		return null
	return _current._settings


func resolve_path(template: String) -> String:
	return template.replace("{game_id}", _resolve_game_id())


func _resolve_game_id() -> String:
	var manifest: VNEngineGameManifest = _game.get_manifest() if _game != null else null
	var id: String = ""
	if manifest != null:
		id = manifest.game_id.strip_edges()
	if id == "":
		id = content_root.trim_suffix("/").get_file()
	id = id.validate_filename()
	if id == "":
		id = "default"
	return id


func get_card_overlay() -> VNEngineCardOverlay:
	return system_layer.get_node_or_null("CardOverlay") as VNEngineCardOverlay
