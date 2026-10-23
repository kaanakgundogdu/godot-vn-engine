class_name VNEngineAnimationRegistry
extends RefCounted

const _ANIM_BOUNCE: GDScript = preload("res://addons/vn_engine/src/animations/anim_bounce.gd")
const _ANIM_SHAKE: GDScript = preload("res://addons/vn_engine/src/animations/anim_shake.gd")
const _ANIM_NOD: GDScript = preload("res://addons/vn_engine/src/animations/anim_nod.gd")
const _ANIM_JUMP: GDScript = preload("res://addons/vn_engine/src/animations/anim_jump.gd")

const NAMES: PackedStringArray = ["bounce", "shake", "nod", "jump"]

const SCRIPTS: Dictionary = {
	"bounce": _ANIM_BOUNCE,
	"shake": _ANIM_SHAKE,
	"nod": _ANIM_NOD,
	"jump": _ANIM_JUMP,
}

var _user_scripts: Dictionary = {}


static func builtin_names() -> PackedStringArray:
	return NAMES


static func user_names() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var root: String = VNEnginePaths.content_root()
	if root == "":
		return result
	for file_name in DirAccess.get_files_at(_user_dir()):
		var base: String = file_name
		if base.ends_with(".remap"):
			base = base.trim_suffix(".remap")
		if base.ends_with(".gd"):
			base = base.trim_suffix(".gd")
		elif base.ends_with(".gdc"):
			base = base.trim_suffix(".gdc")
		else:
			continue
		if not result.has(base):
			result.append(base)
	return result


static func known_names() -> PackedStringArray:
	var result: PackedStringArray = NAMES.duplicate()
	for user_name in user_names():
		if not result.has(user_name):
			result.append(user_name)
	return result


static func has_animation(anim_name: String) -> bool:
	return NAMES.has(anim_name) or user_names().has(anim_name)


static func _user_dir() -> String:
	return VNEnginePaths.content_root().path_join("animations")


func play_on_character(char_id: String, anim_name: String, params: Dictionary, ctx: VNEngineCommandContext) -> void:
	var script: GDScript = _find_script(anim_name)
	if script == null:
		VNEngineLog.warn("Animation", "Unknown animation '%s'" % anim_name)
		return
	if ctx.characters == null or not ctx.characters.active_sprites.has(char_id):
		VNEngineLog.warn("Animation", "'%s' skipped, %s is not on screen" % [anim_name, char_id])
		return
	if ctx.runner != null and ctx.runner.is_skip:
		VNEngineLog.info("Animation", "'%s' on %s skipped" % [anim_name, char_id])
		return

	var message: String = "'%s' on %s" % [anim_name, char_id]
	if not params.is_empty():
		var parts: PackedStringArray = PackedStringArray()
		for key in params:
			parts.append("%s=%s" % [key, params[key]])
		message += " (%s)" % ", ".join(parts)
	VNEngineLog.info("Animation", message)

	var sprite: VNEngineCharacterSprite = ctx.characters.active_sprites[char_id]
	var anim: VNEngineAnimation = script.new() as VNEngineAnimation
	anim.id = anim_name
	await anim.play(sprite, params)


func _find_script(anim_name: String) -> GDScript:
	if _user_scripts.has(anim_name):
		return _user_scripts[anim_name]
	if VNEnginePaths.content_root() != "" and user_names().has(anim_name):
		var loaded: GDScript = load(_user_dir().path_join(anim_name + ".gd")) as GDScript
		if loaded != null:
			_user_scripts[anim_name] = loaded
			return loaded
	return SCRIPTS.get(anim_name, null) as GDScript
