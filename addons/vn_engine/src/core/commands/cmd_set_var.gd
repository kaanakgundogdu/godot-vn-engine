class_name VNEngineCmdSetVar
extends VNEngineCommand

func command_name() -> String:
	return "set_var"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var parts: PackedStringArray = VNEngineExpressionEvaluator.split_assignment(args)
	if parts.is_empty():
		VNEngineLog.warn("CmdSetVar", "Invalid set_var command format: %s" % args)
		return

	var var_name: String = parts[0]
	var operator: String = parts[1]
	var value: Variant = ctx.runner.evaluate_assignment(parts[2])
	var current_val: Variant = ctx.state.get_flag(var_name, 0)

	match operator:
		"=":
			ctx.state.set_flag(var_name, value)
		"+=", "-=", "*=":
			ctx.state.set_flag(var_name, VNEngineExpressionEvaluator.apply_op(current_val, operator, value))
		"/=":
			if not VNEngineExpressionEvaluator.is_zero(value):
				ctx.state.set_flag(var_name, VNEngineExpressionEvaluator.apply_op(current_val, operator, value))
