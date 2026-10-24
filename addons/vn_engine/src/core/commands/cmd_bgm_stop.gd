class_name VNEngineCmdBgmStop
extends VNEngineCommand

func command_name() -> String:
	return "bgm_stop"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var fade: float = VNEngineAudioSystem.split_fade(args)["fade"]
	ctx.state.audio.erase("music")
	if ctx.audio:
		ctx.audio.stop_channel("music", fade)
