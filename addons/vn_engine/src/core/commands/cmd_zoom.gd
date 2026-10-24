class_name VNEngineCmdZoom
extends VNEngineCommand

func command_name() -> String:
	return "zoom"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var tokens := args.strip_edges().split(" ", false)
	if tokens.is_empty():
		VNEngineLog.warn("CmdZoom", "Missing argument: '@zoom' expects a scale or 'reset'")
		return

	var view_scale := 1.0
	var focus := Vector2(0.5, 0.5)
	var focus_x := 0.5
	var focus_y := 0.5
	var time := 1.0
	var i := 1

	if tokens[0].to_lower() != "reset":
		if not tokens[0].is_valid_float():
			VNEngineLog.warn("CmdZoom", "Scale must be a number: '%s'" % tokens[0])
			return
		view_scale = maxf(tokens[0].to_float(), 1.0)

	while i < tokens.size():
		var token := tokens[i]
		if token == "at" and i + 2 < tokens.size() and tokens[i + 1].is_valid_float() and tokens[i + 2].is_valid_float():
			focus_x = clampf(tokens[i + 1].to_float(), 0.0, 1.0)
			focus_y = clampf(tokens[i + 2].to_float(), 0.0, 1.0)
			focus = Vector2(focus_x, focus_y)
			i += 3
			continue
		if token.begins_with("time="):
			var number := token.substr(5)
			if number.is_valid_float():
				time = maxf(number.to_float(), 0.0)
		i += 1

	if view_scale <= 1.0:
		ctx.state.bg_view = {}
	else:
		ctx.state.bg_view = {"scale": view_scale, "x": focus_x, "y": focus_y}

	if ctx.background:
		ctx.background.set_view(view_scale, focus, time)
