class_name VNEngineCharacterLayer
extends Control

@export var runner: VNEngineStoryRunner
@export var sprite_scene: PackedScene
@export var cast: VNEngineCast
@export var positions: Dictionary = {
	"far_left": 0.1,
	"left": 0.25,
	"center": 0.5,
	"right": 0.75,
	"far_right": 0.9,
}

var active_sprites: Dictionary = {}


func _ready() -> void:
	if cast == null:
		var db_path: String = VNEnginePaths.cast_file()
		if ResourceLoader.exists(db_path):
			var db: VNEngineCast = load(db_path) as VNEngineCast
			if db != null:
				cast = db
			else:
				VNEngineLog.warn("CharacterLayer", "'%s' is not a Cast resource" % db_path)
		else:
			VNEngineLog.warn("CharacterLayer", "Character database not found: '%s'" % db_path)

	if runner:
		runner.register_manager(self)
		runner.dialog_started.connect(_on_dialog_started)
		runner.state_restored.connect(_on_state_restored)


func show_character(id: String, outfit: String, pose: String, expression: String, shot: String, position_str: String, transition: String) -> void:
	var key := id.to_lower()
	var entry := _get_db_entry(key)

	var out := outfit
	if out == "" and entry != null:
		out = entry.default_outfit
	var ps := pose
	if ps == "" and entry != null:
		ps = entry.default_pose
	var sh := shot
	if sh == "" and entry != null:
		sh = entry.default_shot

	if active_sprites.has(key):
		var existing: VNEngineCharacterSprite = active_sprites[key]
		if expression != "":
			var existing_path := runner.ctx.assets.resolve_character(key, out, ps, expression, sh)
			existing.set_expression(existing_path)
		if position_str != "":
			existing.move_to(_resolve_position(position_str), 0.4)
		return

	var expr := expression
	if expr == "" and entry != null:
		expr = entry.default_expression
	var pos := position_str if position_str != "" else "center"

	var sprite := sprite_scene.instantiate() as VNEngineCharacterSprite
	add_child(sprite)
	active_sprites[key] = sprite

	var path := runner.ctx.assets.resolve_character(key, out, ps, expr, sh)
	sprite.set_expression(path)

	if entry != null and entry.sprite_scale != 1.0:
		sprite.offset_left *= entry.sprite_scale
		sprite.offset_right *= entry.sprite_scale
		sprite.offset_top *= entry.sprite_scale

	var ratio := _resolve_position(pos)
	sprite.anchor_left = ratio
	sprite.anchor_right = ratio

	sprite.enter(transition)


func hide_character(id: String, transition: String) -> void:
	var key := id.to_lower()
	if not active_sprites.has(key):
		return
	var sprite: VNEngineCharacterSprite = active_sprites[key]
	sprite.exit(transition)
	active_sprites.erase(key)


func move_character(id: String, position_str: String, duration: float) -> void:
	var key := id.to_lower()
	if not active_sprites.has(key):
		return
	active_sprites[key].move_to(_resolve_position(position_str), duration)


func _resolve_position(pos_str: String) -> float:
	if positions.has(pos_str):
		return positions[pos_str]
	if pos_str.is_valid_float():
		return pos_str.to_float()
	VNEngineLog.warn("CharacterLayer", "Unknown position '%s', defaulting to 0.5 (center)" % pos_str)
	return 0.5


func _get_db_entry(id: String) -> VNEngineCastMember:
	if cast == null:
		return null
	return cast.get_entry(id)


func _on_dialog_started(node: VNEngineStoryNode) -> void:
	var speaker := node.speaker_id.to_lower()
	if speaker.is_empty():
		return
	if not active_sprites.has(speaker):
		return

	for char_id in active_sprites.keys():
		if char_id == speaker:
			active_sprites[char_id].focus()
		else:
			active_sprites[char_id].unfocus()


func _on_state_restored(state: VNEngineStoryState) -> void:
	for char_id in active_sprites.keys():
		active_sprites[char_id].queue_free()
	active_sprites.clear()

	for id in state.characters.keys():
		var value: Variant = state.characters[id]
		var expr := ""
		var pos := "center"

		var outfit := ""
		var pose := ""
		var shot := ""

		if typeof(value) == TYPE_STRING:
			expr = value
		elif typeof(value) == TYPE_DICTIONARY:
			expr = value.get("expression", "")
			pos = value.get("position", "center")
			outfit = value.get("outfit", "")
			pose = value.get("pose", "")
			shot = value.get("shot", "")

		show_character(id, outfit, pose, expr, shot, pos, "instant")

	var last_speaker := state.last_speaker
	for char_id in active_sprites.keys():
		if char_id == last_speaker:
			active_sprites[char_id].focus()
		else:
			active_sprites[char_id].unfocus()
