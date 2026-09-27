class_name VNEngineCreditsScreen
extends VNEngineScreen


var _allow_skip: bool = true
var _scroll_speed: float = 60.0
var _using_movie: bool = false
var _finished_called: bool = false

@onready var background_rect: TextureRect = %CreditsBackgroundRect
@onready var scroll_viewport: Control = %CreditsScrollViewport
@onready var content_box: VBoxContainer = %CreditsContent
@onready var video_player: VideoStreamPlayer = %CreditsVideoPlayer


func _process(delta: float) -> void:
	if _using_movie or _finished_called:
		return

	content_box.position.y -= _scroll_speed * delta

	if content_box.position.y + content_box.size.y < 0.0:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if not _allow_skip:
		return
	if not event.is_action_pressed(VNEngineInput.ADVANCE):
		return

	if _using_movie:
		if video_player.is_playing():
			video_player.stop()
			get_viewport().set_input_as_handled()
			_finish()
	else:
		get_viewport().set_input_as_handled()
		_finish()


func screen_id() -> StringName:
	return &"credits"


func enter(params: Dictionary) -> void:
	video_player.hide()

	var def: VNEngineCreditsDef = null
	if VNEngineMain.game().manifest != null:
		def = VNEngineMain.game().manifest.credits
	if def == null:
		VNEngineLog.warn("CreditsScreen", "GameManifest.credits is missing, skipping credits")
		_finish()
		return

	var requested_variant: String = String(params.get("variant", ""))
	if requested_variant != "" and requested_variant != def.variant:
		VNEngineLog.warn("CreditsScreen", "credits_variant '%s' has no matching CreditsDef, using '%s'" % [requested_variant, def.variant])

	_allow_skip = def.allow_skip
	_scroll_speed = maxf(def.scroll_speed, 1.0)

	var resolver: VNEngineAssetResolver = VNEngineMain.game().get_shared_asset_resolver()
	if def.background != "":
		var bg_path: String = resolver.resolve("background", def.background)
		if bg_path != "":
			background_rect.texture = load(bg_path)

	var persistent_audio: VNEngineAudioSystem = VNEngineMain.instance().persistent_audio

	if def.movie != "":
		var movie_path: String = resolver.resolve("movie", def.movie)
		if movie_path != "":
			persistent_audio.stop_bgm()
			_using_movie = true
			scroll_viewport.hide()
			video_player.show()
			video_player.stream = load(movie_path)
			video_player.finished.connect(_finish)
			video_player.play()
			return
		else:
			VNEngineLog.warn("CreditsScreen", "Could not resolve movie '%s', falling back to scrolling credits" % def.movie)

	if def.bgm != "":
		var music_path: String = resolver.resolve("music", def.bgm)
		if music_path != "":
			persistent_audio.play_bgm(music_path, true)
		else:
			persistent_audio.stop_bgm()
	else:
		persistent_audio.stop_bgm()

	_build_sections(def)
	set_process(true)


func _build_sections(def: VNEngineCreditsDef) -> void:
	for section in def.sections:
		if section == null:
			continue

		var role_label := Label.new()
		role_label.text = section.role
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_label.theme_type_variation = &"VNSubheadingLabel"
		role_label.add_theme_color_override("font_color", Color(0.45, 0.8, 1.0, 1.0))
		content_box.add_child(role_label)

		if not section.names.is_empty():
			var names_label := Label.new()
			names_label.text = "\n".join(section.names)
			names_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			names_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			names_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85, 1.0))
			names_label.add_theme_constant_override("line_spacing", 6)
			content_box.add_child(names_label)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 48)
		content_box.add_child(spacer)

	if def.end_logo != "":
		var logo_resolver: VNEngineAssetResolver = VNEngineMain.game().get_shared_asset_resolver()
		var logo_path: String = logo_resolver.resolve("background", def.end_logo)
		if logo_path != "":
			var logo_rect := TextureRect.new()
			logo_rect.texture = load(logo_path)
			logo_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			logo_rect.custom_minimum_size = Vector2(0, 200)
			content_box.add_child(logo_rect)

	content_box.position.y = get_viewport_rect().size.y


func exit() -> void:
	VNEngineMain.instance().persistent_audio.stop_bgm()


func _finish() -> void:
	if _finished_called:
		return
	_finished_called = true
	set_process(false)
	VNEngineMain.game().return_to_title()
