@tool
class_name VNEngineCommandRegistry
extends RefCounted

const COMMANDS_DIR := "res://addons/vn_engine/src/core/commands/"

const _CMD_BG: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_bg.gd")
const _CMD_CG: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_cg.gd")
const _CMD_CG_HIDE: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_cg_hide.gd")
const _CMD_SHOW: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_show.gd")
const _CMD_HIDE: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_hide.gd")
const _CMD_LEAVE: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_leave.gd")
const _CMD_MOVE: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_move.gd")
const _CMD_SHAKE: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_shake.gd")
const _CMD_TRANSITION: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_transition.gd")
const _CMD_WINDOW: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_window.gd")
const _CMD_MUSIC: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_music.gd")
const _CMD_BGM_STOP: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_bgm_stop.gd")
const _CMD_SFX: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_sfx.gd")
const _CMD_VOICE: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_voice.gd")
const _CMD_MOVIE: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_movie.gd")
const _CMD_SET_VAR: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_set_var.gd")
const _CMD_FLAG: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_flag.gd")
const _CMD_JUMP: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_jump.gd")
const _CMD_JUMP_IF: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_jump_if.gd")
const _CMD_CALL: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_call.gd")
const _CMD_RETURN: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_return.gd")
const _CMD_SCENE: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_scene.gd")
const _CMD_WAIT: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_wait.gd")
const _CMD_END: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_end.gd")
const _CMD_GOTO_CHAPTER: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_goto_chapter.gd")
const _CMD_CREDITS: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_credits.gd")
const _CMD_CHOICE_TIMER: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_choice_timer.gd")
const _CMD_CHAPTER_TITLE: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_chapter_title.gd")
const _CMD_EYECATCH: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_eyecatch.gd")
const _CMD_DATECARD: GDScript = preload("res://addons/vn_engine/src/core/commands/cmd_datecard.gd")

const NAMES: PackedStringArray = [
	"bg", "cg", "cg_hide", "show", "hide", "leave", "move", "shake",
	"transition", "window",
	"music", "bgm_stop", "sfx", "voice", "movie",
	"set_var", "flag", "jump", "jump_if", "call", "return", "scene", "wait",
	"end", "goto_chapter", "credits", "choice_timer",
	"chapter_title", "eyecatch", "datecard",
]

const SCRIPTS: Dictionary = {
	"bg": _CMD_BG,
	"cg": _CMD_CG,
	"cg_hide": _CMD_CG_HIDE,
	"show": _CMD_SHOW,
	"hide": _CMD_HIDE,
	"leave": _CMD_LEAVE,
	"move": _CMD_MOVE,
	"shake": _CMD_SHAKE,
	"transition": _CMD_TRANSITION,
	"window": _CMD_WINDOW,
	"music": _CMD_MUSIC,
	"bgm_stop": _CMD_BGM_STOP,
	"sfx": _CMD_SFX,
	"voice": _CMD_VOICE,
	"movie": _CMD_MOVIE,
	"set_var": _CMD_SET_VAR,
	"flag": _CMD_FLAG,
	"jump": _CMD_JUMP,
	"jump_if": _CMD_JUMP_IF,
	"call": _CMD_CALL,
	"return": _CMD_RETURN,
	"scene": _CMD_SCENE,
	"wait": _CMD_WAIT,
	"end": _CMD_END,
	"goto_chapter": _CMD_GOTO_CHAPTER,
	"credits": _CMD_CREDITS,
	"choice_timer": _CMD_CHOICE_TIMER,
	"chapter_title": _CMD_CHAPTER_TITLE,
	"eyecatch": _CMD_EYECATCH,
	"datecard": _CMD_DATECARD,
}


static func known_names() -> PackedStringArray:
	return NAMES


static func is_known(command_name: String) -> bool:
	return NAMES.has(command_name)


static func script_path(command_name: String) -> String:
	return COMMANDS_DIR + "cmd_%s.gd" % command_name


static func register_all(bus: VNEngineCommandBus) -> void:
	for command_name in NAMES:
		var script: GDScript = SCRIPTS.get(command_name, null) as GDScript
		var cmd: VNEngineCommand = script.new() as VNEngineCommand
		bus.register(cmd)
