class_name VNEngineCmdEnd
extends VNEngineCommand

func command_name() -> String:
	return "end"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var parsed := split_options(args)
	ctx.runner.end_story(VNEngineStoryRunner.EndReason.EXPLICIT_END, parsed.id, parsed.transition)
	ctx.runner._jumped = true

static func split_options(args: String) -> Dictionary:
	var id := ""
	var transition: Dictionary = {}
	for token: String in args.split(" ", false):
		if token.begins_with("transition="):
			var kind := token.substr(11)
			if kind != "":
				transition["kind"] = kind
		elif token.begins_with("time="):
			var number := token.substr(5)
			if number.is_valid_float() and number.to_float() >= 0.0:
				transition["time"] = number.to_float()
		elif not token.contains("=") and id == "":
			id = token
	return {"id": id, "transition": transition}
