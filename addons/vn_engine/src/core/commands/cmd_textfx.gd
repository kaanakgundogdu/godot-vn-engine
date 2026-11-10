class_name VNEngineCmdTextFx
extends VNEngineCommand

const TYPES: PackedStringArray = ["glitch"]

func command_name() -> String:
	return "textfx"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var tokens := args.strip_edges().split(" ", false)
	if tokens.is_empty():
		VNEngineLog.warn("CmdTextFx", "Missing argument: '@textfx' expects glitch or off")
		return

	var type := tokens[0].to_lower()
	if type != "off" and not TYPES.has(type):
		VNEngineLog.warn("CmdTextFx", "Unknown text effect: '%s'" % tokens[0])
		return

	if type == "off":
		ctx.state.text_fx = {}
	else:
		var strength := 0.6
		for i in range(1, tokens.size()):
			var token := tokens[i]
			if token.begins_with("strength="):
				var number := token.substr(9)
				if number.is_valid_float():
					strength = clampf(number.to_float(), 0.05, 1.0)
		ctx.state.text_fx = {"type": type, "strength": strength}

	if ctx.dialog_ui:
		ctx.dialog_ui.refresh_text_fx()
