class_name VNEngineCmdHide
extends VNEngineCommand

func command_name() -> String:
	return "hide"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var tokens := args.strip_edges().split(" ", false)
	if tokens.is_empty():
		VNEngineLog.warn("CmdHide", "Missing argument: '@hide' expects a character id")
		return

	var id := tokens[0].to_lower()
	var transition := "fade"

	var i := 1
	while i < tokens.size():
		if tokens[i] == "with" and i + 1 < tokens.size():
			transition = tokens[i + 1]
			i += 2
		else:
			i += 1

	ctx.state.characters.erase(id)

	if ctx.characters:
		ctx.characters.hide_character(id, transition)
