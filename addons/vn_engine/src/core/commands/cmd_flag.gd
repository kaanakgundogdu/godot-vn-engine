class_name VNEngineCmdFlag
extends VNEngineCommand

func command_name() -> String:
	return "flag"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var tokens: PackedStringArray = VNEngineExpressionEvaluator.split_assignment(args)
	if tokens.is_empty():
		VNEngineLog.warn("CmdFlag", "Invalid '@flag' format: %s" % args)
		return

	var flag_id: String = tokens[0]
	var op: String = tokens[1]

	var flag_list: VNEngineFlagList = ctx.runner.flag_list

	var value: Variant = ctx.runner.evaluate_assignment(tokens[2])
	var new_value: Variant
	if op == "=":
		new_value = value
	elif op == "+=" or op == "-=" or op == "*=" or op == "/=":
		if op == "/=" and VNEngineExpressionEvaluator.is_zero(value):
			VNEngineLog.warn("CmdFlag", "Division by zero, no change made: %s" % args)
			return
		var current: Variant = ctx.state.get_flag(flag_id, 0)
		new_value = VNEngineExpressionEvaluator.apply_op(current, op, value)
	else:
		VNEngineLog.warn("CmdFlag", "Unknown operator: '%s' (%s)" % [op, args])
		return

	if flag_list != null:
		new_value = flag_list.coerce(flag_id, new_value)

	ctx.state.set_flag(flag_id, new_value)

	if flag_list != null:
		var def: VNEngineFlagDef = flag_list.find(flag_id)
		if def != null and def.scope == "global":
			VNEngineMain.save_data().set_global_flag(flag_id, new_value)
