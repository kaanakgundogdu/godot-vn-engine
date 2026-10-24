class_name VNEngineCmdAmbient
extends VNEngineCommand

func command_name() -> String:
	return "ambient"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var parsed: Dictionary = VNEngineAudioSystem.split_fade(args)
	var value: String = parsed["value"]
	var fade: float = parsed["fade"]

	if value.to_lower() == "stop":
		ctx.state.audio.erase("ambient")
	else:
		ctx.state.audio["ambient"] = value

	if ctx.audio:
		ctx.audio.play_channel("ambient", value, "", fade)
