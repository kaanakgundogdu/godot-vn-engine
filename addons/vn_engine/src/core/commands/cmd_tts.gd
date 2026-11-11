class_name VNEngineCmdTts
extends VNEngineCommand

func command_name() -> String:
	return "tts"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var text := args.strip_edges()
	if text.length() < 2 or not text.begins_with("\"") or not text.ends_with("\""):
		VNEngineLog.warn("CmdTts", "'@tts' expects text in quotes")
		return
	var speech: VNEngineSpeech = VNEngineMain.speech()
	if speech != null and not (ctx.runner != null and ctx.runner.is_skip):
		speech.speak(VNEngineTextMarkup.interpolate(text.substr(1, text.length() - 2), ctx.state.flags))
