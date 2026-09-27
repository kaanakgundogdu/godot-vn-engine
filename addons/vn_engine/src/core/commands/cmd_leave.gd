class_name VNEngineCmdLeave
extends VNEngineCommand

func command_name() -> String:
	return "leave"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	VNEngineCmdHide.new().apply(args, ctx)
