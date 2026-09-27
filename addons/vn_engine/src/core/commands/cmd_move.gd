class_name VNEngineCmdMove
extends VNEngineCommand

func command_name() -> String:
	return "move"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var tokens := args.strip_edges().split(" ", false)
	if tokens.is_empty():
		VNEngineLog.warn("CmdMove", "Missing argument: '@move' expects a character id")
		return

	var id := tokens[0].to_lower()
	var position := ""
	var duration := 0.4

	var i := 1
	while i < tokens.size():
		if tokens[i] == "to" and i + 1 < tokens.size():
			position = tokens[i + 1]
			i += 2
		elif tokens[i] == "over" and i + 1 < tokens.size():
			duration = tokens[i + 1].to_float()
			i += 2
		else:
			i += 1

	if position == "":
		VNEngineLog.warn("CmdMove", "'@move %s' expects a 'to <position>'" % id)
		return

	if ctx.state.characters.has(id):
		var value: Variant = ctx.state.characters[id]
		if typeof(value) == TYPE_DICTIONARY:
			value["position"] = position
		elif typeof(value) == TYPE_STRING:
			ctx.state.characters[id] = {"expression": value, "position": position}

	if ctx.characters:
		ctx.characters.move_character(id, position, duration)
