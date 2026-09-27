class_name VNEngineCmdBg
extends VNEngineCommand

func command_name() -> String:
	return "bg"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var tokens := args.strip_edges().split(" ", false)
	if tokens.is_empty():
		VNEngineLog.warn("CmdBg", "Missing argument: '@bg' expects a background name")
		return

	var bg_name := tokens[0]
	var transition := "fade"
	var duration := -1.0

	var i := 1
	if i < tokens.size() and tokens[i] == "with" and i + 1 < tokens.size():
		transition = tokens[i + 1]
		i += 2

	if i < tokens.size() and tokens[i].is_valid_float():
		duration = tokens[i].to_float()

	ctx.state.bg = bg_name

	if ctx.background:
		ctx.background.change_to(bg_name, transition, duration)
