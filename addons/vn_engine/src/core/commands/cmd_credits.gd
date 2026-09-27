class_name VNEngineCmdCredits
extends VNEngineCommand

func command_name() -> String:
	return "credits"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	VNEngineMain.game().play_credits(args.strip_edges())
	ctx.runner._jumped = true
