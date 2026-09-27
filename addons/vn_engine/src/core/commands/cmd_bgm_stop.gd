class_name VNEngineCmdBgmStop
extends VNEngineCommand

func command_name() -> String:
	return "bgm_stop"

func apply(_args: String, ctx: VNEngineCommandContext) -> void:
	ctx.state.audio.erase("music")
	if ctx.audio:
		ctx.audio.play_channel("music", "stop")
