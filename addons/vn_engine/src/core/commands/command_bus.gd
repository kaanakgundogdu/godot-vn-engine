class_name VNEngineCommandBus
extends RefCounted

signal blocked_finished

var _commands: Dictionary = {}
var _pending_block: bool = false


func register(cmd: VNEngineCommand) -> void:
	_commands[cmd.command_name()] = cmd


func apply(name: String, args: String, ctx: VNEngineCommandContext) -> void:
	if not _commands.has(name):
		VNEngineLog.warn("CommandBus", "Unknown command, skipping: '@%s'" % name)
		return

	var cmd: VNEngineCommand = _commands[name]

	if cmd.is_blocking():
		_pending_block = true

	cmd.apply(args, ctx)


func has_pending_block() -> bool:
	return _pending_block


func resolve_block() -> void:
	_pending_block = false
	blocked_finished.emit()
