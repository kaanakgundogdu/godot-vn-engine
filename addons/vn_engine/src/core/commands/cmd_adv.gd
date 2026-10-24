class_name VNEngineCmdAdv
extends VNEngineCommand

func command_name() -> String:
	return "adv"

func apply(_args: String, ctx: VNEngineCommandContext) -> void:
	ctx.runner.set_text_mode("adv")
