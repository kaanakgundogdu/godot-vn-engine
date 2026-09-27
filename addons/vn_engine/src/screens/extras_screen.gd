class_name VNEngineExtrasScreen
extends VNEngineScreen


const TAB_INDEX: Dictionary = {
	&"gallery": 0,
	&"music": 1,
	&"endings": 2,
	&"movies": 3,
}

var _gallery_instance: VNEngineGalleryPanel = null

var _extras_def: VNEngineExtrasDef = null

var _music_playing_id: String = ""
var _music_playing_btn: Button = null

@onready var tabs: TabContainer = %ExtrasTabs
@onready var back_btn: Button = %BackButton
@onready var gallery_tab_root: Control = %GalleryTabRoot
@onready var music_list: VBoxContainer = %MusicList
@onready var endings_list: VBoxContainer = %EndingsList
@onready var endings_counter_label: Label = %EndingsCounterLabel
@onready var movies_list: VBoxContainer = %MoviesList
@onready var music_preview_player: AudioStreamPlayer = %MusicPreviewPlayer


func _ready() -> void:
	tabs.tab_changed.connect(_on_tab_changed)
	music_preview_player.finished.connect(_on_music_preview_finished)
	back_btn.pressed.connect(_on_back_pressed)


func screen_id() -> StringName:
	return &"extras"


func enter(params: Dictionary) -> void:
	_extras_def = _get_extras_def()

	var requested_tab: StringName = params.get("tab", &"gallery")
	if not TAB_INDEX.has(requested_tab):
		VNEngineLog.warn("ExtrasScreen", "Unknown tab parameter: '%s', falling back to 'gallery'" % requested_tab)
		requested_tab = &"gallery"

	_apply_tab_visibility(_extras_def)

	_populate_gallery_tab()
	_populate_music_tab()
	_populate_endings_tab()
	_populate_movies_tab()

	var target_index: int = TAB_INDEX[requested_tab]
	if tabs.is_tab_hidden(target_index):
		target_index = _first_visible_tab_index()
	tabs.current_tab = target_index


func exit() -> void:
	_stop_music_preview()


func allows_overlay(id: StringName) -> bool:
	if id == &"gallery":
		return false
	return true


func handle_back() -> bool:
	return _dismiss_or_leave()


func handle_alt_click() -> bool:
	return _dismiss_or_leave()


func _dismiss_or_leave() -> bool:
	if VNEngineMain.instance().get_card_overlay().visible:
		return true

	if _gallery_instance != null and _gallery_instance.handle_back():
		return true

	VNEngineMain.game().return_to_title()
	return true


func _on_back_pressed() -> void:
	handle_back()


func _on_tab_changed(tab_index: int) -> void:
	if tab_index != TAB_INDEX[&"music"]:
		_stop_music_preview()


func _get_extras_def() -> VNEngineExtrasDef:
	var manifest: VNEngineGameManifest = VNEngineMain.game().get_manifest()
	if manifest == null:
		return VNEngineExtrasDef.new()
	return manifest.get_extras()


func _apply_tab_visibility(def: VNEngineExtrasDef) -> void:
	tabs.set_tab_hidden(TAB_INDEX[&"gallery"], not def.show_gallery)
	tabs.set_tab_hidden(TAB_INDEX[&"music"], not def.show_music)
	tabs.set_tab_hidden(TAB_INDEX[&"endings"], not def.show_endings)
	tabs.set_tab_hidden(TAB_INDEX[&"movies"], not def.show_movies)


func _first_visible_tab_index() -> int:
	for i in tabs.get_tab_count():
		if not tabs.is_tab_hidden(i):
			return i
	return 0


func _build_entries(kind: String, def_items: Array[VNEngineExtrasItem], resolver: VNEngineAssetResolver) -> Array[VNEngineExtrasItem]:
	var result: Array[VNEngineExtrasItem] = []

	if not def_items.is_empty():
		for item: VNEngineExtrasItem in def_items:
			if item == null or item.id == "":
				continue
			if resolver.resolve(kind, item.id) == "":
				continue
			result.append(item)
		return result

	for id: String in resolver.list_all(kind):
		var default_item: VNEngineExtrasItem = VNEngineExtrasItem.new()
		default_item.id = id
		result.append(default_item)
	return result


func _display_name(item: VNEngineExtrasItem, unlocked: bool, def: VNEngineExtrasDef) -> String:
	if unlocked:
		return item.title if item.title != "" else item.id
	return item.locked_text if item.locked_text != "" else def.locked_name_text


func _populate_gallery_tab() -> void:
	if _gallery_instance != null:
		return

	var gallery_scene: PackedScene = VNEngineMain.instance().overlay_stack.scene_for(&"gallery")
	var instance: VNEngineGalleryPanel = gallery_scene.instantiate() as VNEngineGalleryPanel
	gallery_tab_root.add_child(instance)
	_gallery_instance = instance

	var close_btn: Button = instance.get_node("%CloseGalleryButton") as Button
	close_btn.hide()

	instance.set_extras_def(_extras_def)
	instance.set_asset_resolver(VNEngineMain.game().get_shared_asset_resolver())
	instance.open_panel()


func _populate_music_tab() -> void:
	_clear_children(music_list)

	var resolver: VNEngineAssetResolver = VNEngineMain.game().get_shared_asset_resolver()
	var entries: Array[VNEngineExtrasItem] = _build_entries("music", _extras_def.music_items, resolver)
	if entries.is_empty():
		_add_info_row(music_list, "No music yet.")
		return

	for item: VNEngineExtrasItem in entries:
		var unlocked: bool = VNEngineMain.save_data().is_music_unlocked(item.id)
		if item.hidden_until_unlocked and not unlocked:
			continue
		_add_music_row(item, unlocked)


func _add_music_row(item: VNEngineExtrasItem, unlocked: bool) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(0, 60)

	var name_label: Label = Label.new()
	name_label.text = _display_name(item, unlocked, _extras_def)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	if unlocked:
		var play_btn: Button = Button.new()
		play_btn.text = "Play"
		play_btn.theme_type_variation = &"VNSmallButton"
		play_btn.custom_minimum_size = Vector2(140, 56)
		play_btn.pressed.connect(_on_music_play_pressed.bind(item.id, play_btn))
		row.add_child(play_btn)

	music_list.add_child(row)


func _on_music_play_pressed(id: String, btn: Button) -> void:
	if _music_playing_id == id and music_preview_player.playing:
		_stop_music_preview()
		return

	var resolver: VNEngineAssetResolver = VNEngineMain.game().get_shared_asset_resolver()
	var path: String = resolver.resolve("music", id)
	if path == "":
		return

	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return

	_stop_music_preview()
	music_preview_player.stream = stream
	music_preview_player.play()
	_music_playing_id = id
	_music_playing_btn = btn
	btn.text = "Stop"


func _on_music_preview_finished() -> void:
	if _music_playing_btn != null:
		_music_playing_btn.text = "Play"
	_music_playing_id = ""
	_music_playing_btn = null


func _stop_music_preview() -> void:
	music_preview_player.stop()
	if _music_playing_btn != null:
		_music_playing_btn.text = "Play"
	_music_playing_id = ""
	_music_playing_btn = null


func _populate_endings_tab() -> void:
	_clear_children(endings_list)

	var manifest: VNEngineGameManifest = VNEngineMain.game().get_manifest()
	if manifest == null or manifest.endings.is_empty():
		_add_info_row(endings_list, "Ending info unavailable.")
		endings_counter_label.text = "0 / 0"
		return

	var seen_count: int = 0
	for ending: VNEngineEndingDef in manifest.endings:
		if ending == null:
			continue
		var seen: bool = VNEngineMain.save_data().is_ending_seen(ending.id)
		if seen:
			seen_count += 1
		_add_ending_row(ending, seen)

	endings_counter_label.text = "%d / %d" % [seen_count, manifest.endings.size()]


func _add_ending_row(ending: VNEngineEndingDef, seen: bool) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(0, 60)

	if not seen and ending.is_secret:
		var hidden_label: Label = Label.new()
		hidden_label.text = _extras_def.secret_ending_text
		hidden_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(hidden_label)
		endings_list.add_child(row)
		return

	var number_label: Label = Label.new()
	number_label.text = "END %02d" % ending.number
	number_label.theme_type_variation = &"VNSmallLabel"
	row.add_child(number_label)

	var title_label: Label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text = ending.title if seen else _extras_def.locked_name_text
	row.add_child(title_label)

	if seen:
		var rank_label: Label = Label.new()
		rank_label.text = ending.rank
		rank_label.theme_type_variation = &"VNSmallLabel"
		row.add_child(rank_label)

	endings_list.add_child(row)


func _populate_movies_tab() -> void:
	_clear_children(movies_list)

	var resolver: VNEngineAssetResolver = VNEngineMain.game().get_shared_asset_resolver()
	var entries: Array[VNEngineExtrasItem] = _build_entries("movie", _extras_def.movie_items, resolver)
	if entries.is_empty():
		_add_info_row(movies_list, "No movies yet.")
		return

	for item: VNEngineExtrasItem in entries:
		var unlocked: bool = VNEngineMain.save_data().is_movie_unlocked(item.id)
		if item.hidden_until_unlocked and not unlocked:
			continue
		_add_movie_row(item, unlocked)


func _add_movie_row(item: VNEngineExtrasItem, unlocked: bool) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(0, 60)

	var name_label: Label = Label.new()
	name_label.text = _display_name(item, unlocked, _extras_def)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	if unlocked:
		var play_btn: Button = Button.new()
		play_btn.text = "Play"
		play_btn.theme_type_variation = &"VNSmallButton"
		play_btn.custom_minimum_size = Vector2(140, 56)
		play_btn.pressed.connect(_on_movie_play_pressed.bind(item.id))
		row.add_child(play_btn)

	movies_list.add_child(row)


func _on_movie_play_pressed(id: String) -> void:
	var resolver: VNEngineAssetResolver = VNEngineMain.game().get_shared_asset_resolver()
	var path: String = resolver.resolve("movie", id)
	if path == "":
		return

	VNEngineMain.instance().get_card_overlay().open(VNEngineCardOverlay.MODE_MOVIE, {"movie_path": path})


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _add_info_row(container: Node, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	container.add_child(label)
