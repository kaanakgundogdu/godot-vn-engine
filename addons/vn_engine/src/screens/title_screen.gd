class_name VNEngineTitleScreen
extends VNEngineScreen

const LOGO_TIME: float = 0.25
const BUTTONS_DELAY: float = 0.1
const SLIDE_DISTANCE: float = 16.0

@onready var continue_btn: Button = %ContinueButton
@onready var new_game_btn: Button = %NewGameButton
@onready var load_game_btn: Button = %LoadGameButton
@onready var settings_btn: Button = %SettingsButton
@onready var quit_btn: Button = %QuitButton
@onready var extras_btn: Button = %GalleryButton
@onready var background_rect: TextureRect = %TitleBackgroundRect
@onready var logo_rect: TextureRect = %TitleLogoRect
@onready var menu_container: MarginContainer = $MainMenuMarginContainer
@onready var menu_vbox: VBoxContainer = $MainMenuMarginContainer/VBoxContainer
@onready var chapter_select_btn: Button = get_node_or_null("%ChapterSelectButton") as Button


var _logo_resolved: bool = false
var _continue_slot: int = -1
var _alignment: String = "center"
var _intro_tweens: Array[Tween] = []
var _blur_tween: Tween = null


func _ready() -> void:
	_connect_signals()
	_init_menu_state()
	_apply_title_variant()
	_apply_menu_alignment()
	_apply_logo()
	_apply_menu_visibility()


func screen_id() -> StringName:
	return &"title"


func enter(_params: Dictionary) -> void:
	_play_intro()


func on_focus() -> void:
	menu_container.show()
	if _logo_resolved:
		logo_rect.show()
	_refresh_continue()
	_grab_default_focus()
	if menu_container.modulate.a < 1.0:
		_fade_menu(1.0)


func on_blur() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and menu_container.is_ancestor_of(focused):
		focused.release_focus()
	if not VNEngineUiMotion.enabled() or VNEngineUiMotion.time(VNEngineOverlayStack.OPEN_TIME) <= 0.0:
		menu_container.hide()
		logo_rect.hide()
		return
	_fade_menu(0.0)


func _input(event: InputEvent) -> void:
	if _intro_tweens.is_empty():
		return
	var skip: bool = event is InputEventMouseButton and event.pressed
	skip = skip or event.is_action_pressed(&"ui_accept")
	for action: StringName in [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]:
		skip = skip or event.is_action_pressed(action)
	if skip:
		_finish_intro()


func _play_intro() -> void:
	var buttons: Array[Control] = []
	for child: Node in menu_vbox.get_children():
		if child is Button:
			buttons.append(child)
	var offset: Vector2 = Vector2(0.0, SLIDE_DISTANCE)
	if _alignment == "left":
		offset = Vector2(-SLIDE_DISTANCE, 0.0)
	elif _alignment == "right":
		offset = Vector2(SLIDE_DISTANCE, 0.0)

	var delay: float = 0.0
	if _logo_resolved and VNEngineUiMotion.enabled():
		logo_rect.modulate.a = 0.0
		var logo_tween: Tween = logo_rect.create_tween()
		logo_tween.tween_property(logo_rect, "modulate:a", 1.0, VNEngineUiMotion.time(LOGO_TIME))
		_intro_tweens.append(logo_tween)
		delay = BUTTONS_DELAY
	var button_tween: Tween = VNEngineUiMotion.stagger_in(buttons, offset, delay)
	if button_tween != null:
		_intro_tweens.append(button_tween)
		button_tween.finished.connect(_on_intro_finished)


func _on_intro_finished() -> void:
	_intro_tweens.clear()


func _finish_intro() -> void:
	var tweens: Array[Tween] = _intro_tweens.duplicate()
	_intro_tweens.clear()
	for tween: Tween in tweens:
		if tween.is_valid():
			tween.custom_step(99.0)


func _fade_menu(target: float) -> void:
	if _blur_tween != null and _blur_tween.is_valid():
		_blur_tween.kill()
	var time: float = VNEngineUiMotion.time(VNEngineOverlayStack.OPEN_TIME)
	if not VNEngineUiMotion.enabled() or time <= 0.0:
		menu_container.modulate.a = target
		logo_rect.modulate.a = target
		return
	_blur_tween = create_tween().set_parallel(true)
	_blur_tween.tween_property(menu_container, "modulate:a", target, time)
	_blur_tween.tween_property(logo_rect, "modulate:a", target, time)
	if target <= 0.0:
		_blur_tween.chain().tween_callback(_hide_menu)


func _hide_menu() -> void:
	menu_container.hide()
	logo_rect.hide()


func _connect_signals() -> void:
	continue_btn.pressed.connect(_on_continue_pressed)
	new_game_btn.pressed.connect(_on_new_game_pressed)
	load_game_btn.pressed.connect(_on_load_game_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	extras_btn.pressed.connect(_on_extras_pressed)
	if chapter_select_btn != null:
		chapter_select_btn.pressed.connect(_on_chapter_select_pressed)


func _init_menu_state() -> void:
	_refresh_continue()
	_grab_default_focus()

	if OS.has_feature("web"):
		quit_btn.hide()


func _refresh_continue() -> void:
	_continue_slot = VNEngineMain.save_data().most_recent_slot()
	continue_btn.visible = _continue_slot != -1


func _grab_default_focus() -> void:
	if continue_btn.visible:
		continue_btn.grab_focus()
	else:
		new_game_btn.grab_focus()


func _apply_title_variant() -> void:
	var game: VNEngineGame = VNEngineMain.game()
	if game.manifest == null or game.manifest.title == null:
		return
	var def: VNEngineTitleScreenDef = game.manifest.title
	var cleared: bool = VNEngineMain.save_data().global_data.get("cleared_count", 0) > 0

	var bg_id: String = def.background
	if cleared and def.cleared_background != "":
		bg_id = def.cleared_background
	var bgm_id: String = def.bgm
	if cleared and def.cleared_bgm != "":
		bgm_id = def.cleared_bgm

	var resolver: VNEngineAssetResolver = game.get_shared_asset_resolver()
	if bg_id != "":
		var bg_path: String = resolver.resolve("background", bg_id)
		if bg_path != "":
			background_rect.texture = load(bg_path)

	var persistent_audio: VNEngineAudioSystem = VNEngineMain.instance().persistent_audio
	if bgm_id != "":
		var music_path: String = resolver.resolve("music", bgm_id)
		if music_path != "":
			persistent_audio.play_bgm(music_path)
	else:
		persistent_audio.stop_bgm()


func _apply_menu_alignment() -> void:
	var alignment: String = "center"
	var game: VNEngineGame = VNEngineMain.game()
	if game.manifest != null and game.manifest.title != null:
		alignment = game.manifest.title.menu_alignment
	_alignment = alignment
	match alignment:
		"left":
			menu_vbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		"right":
			menu_vbox.size_flags_horizontal = Control.SIZE_SHRINK_END
		_:
			menu_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _apply_menu_visibility() -> void:
	var def: VNEngineTitleScreenDef = null
	var game: VNEngineGame = VNEngineMain.game()
	if game.manifest != null:
		def = game.manifest.title
	if def == null:
		def = VNEngineTitleScreenDef.new()

	extras_btn.visible = _visibility_for(def.show_extras_when)

	if chapter_select_btn != null:
		var show: bool = _visibility_for(def.show_chapter_select_when)
		if def.chapter_select_in_debug and OS.is_debug_build():
			show = true
		chapter_select_btn.visible = show


func _visibility_for(when: String) -> bool:
	match when:
		"":
			return true
		"cleared_once":
			return VNEngineMain.save_data().global_data.get("cleared_count", 0) > 0
		"never":
			return false
		_:
			var flags: Dictionary = VNEngineMain.save_data().global_data.get("flags", {})
			return VNEngineExpressionEvaluator.evaluate(when, flags)


func _apply_logo() -> void:
	var logo_value: String = ""
	var game: VNEngineGame = VNEngineMain.game()
	if game.manifest != null and game.manifest.title != null:
		logo_value = game.manifest.title.logo
	if logo_value == "":
		return

	var texture: Texture2D = null
	if logo_value.begins_with("res://"):
		if ResourceLoader.exists(logo_value):
			texture = load(logo_value) as Texture2D
	else:
		var resolver: VNEngineAssetResolver = game.get_shared_asset_resolver()
		var resolved_path: String = resolver.resolve("background", logo_value)
		if resolved_path == "":
			resolved_path = resolver.resolve("cg", logo_value)
		if resolved_path != "":
			texture = load(resolved_path) as Texture2D

	if texture == null:
		VNEngineLog.warn("TitleScreen", "Could not resolve title logo: '%s'" % logo_value)
		return

	logo_rect.texture = texture
	logo_rect.show()
	_logo_resolved = true


func _on_continue_pressed() -> void:
	if _continue_slot != -1:
		VNEngineMain.game().load_slot(_continue_slot)


func _on_new_game_pressed() -> void:
	VNEngineMain.game().start_new_game()


func _on_load_game_pressed() -> void:
	VNEngineMain.game().open_overlay(&"load", {"save_mode": false}).load_requested.connect(_on_load_requested)


func _on_load_requested(slot_id: int) -> void:
	var game: VNEngineGame = VNEngineMain.game()
	game.close_overlay()
	game.load_slot(slot_id)


func _on_settings_pressed() -> void:
	VNEngineMain.game().open_overlay(&"settings")


func _on_extras_pressed() -> void:
	VNEngineMain.instance().screen_stack.push_screen(&"extras")


func _on_chapter_select_pressed() -> void:
	VNEngineMain.instance().screen_stack.push_screen(&"chapter_select")


func _on_quit_pressed() -> void:
	var game: VNEngineGame = VNEngineMain.game()
	var manifest: VNEngineGameManifest = game.get_manifest()
	var ui_def: VNEngineUiDef = manifest.get_ui() if manifest != null else VNEngineUiDef.new()
	if not ui_def.confirm_quit:
		game.quit_game()
		return

	game.open_overlay(&"confirm", {
		"message": "Quit the game?",
		"confirm_text": "Quit",
		"cancel_text": "Cancel",
	}).confirmed.connect(_on_quit_confirmed)


func _on_quit_confirmed() -> void:
	VNEngineMain.game().quit_game()
