class_name VNEngineCmdShake
extends VNEngineCommand

func command_name() -> String:
	return "shake"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	if ctx.camera:
		ctx.camera.shake(args.strip_edges())
