class_name VNEngineCmdCg
extends VNEngineCommand

func command_name() -> String:
	return "cg"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var tokens := args.strip_edges().split(" ", false)
	if tokens.is_empty():
		VNEngineLog.warn("CmdCg", "Missing argument: '@cg' expects a CG id")
		return

	var cg_id := tokens[0]
	var transition := "fade"
	var duration := -1.0

	var i := 1
	if i < tokens.size() and tokens[i] == "with" and i + 1 < tokens.size():
		transition = tokens[i + 1]
		i += 2

	if i < tokens.size() and tokens[i].is_valid_float():
		duration = tokens[i].to_float()

	VNEngineMain.save_data().unlock_cg(cg_id)
	ctx.state.cg = cg_id

	if ctx.characters:
		var active_ids: Array = ctx.characters.active_sprites.keys().duplicate()
		for char_id in active_ids:
			ctx.characters.hide_character(char_id, transition)
		ctx.state.characters.clear()

	if ctx.background:
		ctx.background.change_to(cg_id, transition, duration, "cg")
