class_name VNEngineCmdSetVar
extends VNEngineCommand

func command_name() -> String:
	return "set_var"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var parts := args.split(" ", false)
	if parts.size() < 3:
		VNEngineLog.warn("CmdSetVar", "Invalid set_var command format: %s" % args)
		return

	var var_name := parts[0].strip_edges()
	var operator := parts[1].strip_edges()
	var val_str := parts[2].strip_edges()

	var parsed_val: Variant = val_str

	if val_str.to_lower() == "true":
		parsed_val = true
	elif val_str.to_lower() == "false":
		parsed_val = false
	elif val_str.is_valid_float():
		parsed_val = val_str.to_float()

	var current_val: Variant = ctx.state.get_flag(var_name, 0)

	match operator:
		"=":
			ctx.state.set_flag(var_name, parsed_val)
		"+=":
			ctx.state.set_flag(var_name, current_val + parsed_val)
		"-=":
			ctx.state.set_flag(var_name, current_val - parsed_val)
		"*=":
			ctx.state.set_flag(var_name, current_val * parsed_val)
		"/=":
			if parsed_val != 0:
				ctx.state.set_flag(var_name, current_val / parsed_val)
