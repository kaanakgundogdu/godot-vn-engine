class_name VNEngineCmdFlag
extends VNEngineCommand

func command_name() -> String:
	return "flag"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var tokens: PackedStringArray = args.split(" ", false)
	if tokens.size() < 3:
		VNEngineLog.warn("CmdFlag", "Invalid '@flag' format: %s" % args)
		return

	var flag_id: String = tokens[0].strip_edges()
	var op: String = tokens[1].strip_edges()
	var value_str: String = " ".join(tokens.slice(2))

	var flag_list: VNEngineFlagList = ctx.runner.flag_list

	var new_value: Variant
	if op == "=":
		new_value = _literal(value_str)
	elif op == "+=" or op == "-=" or op == "*=" or op == "/=":
		var current: Variant = ctx.state.get_flag(flag_id, 0)
		var current_f: float = _to_float(current)
		var delta_f: float = _to_float(_literal(value_str))
		match op:
			"+=":
				new_value = current_f + delta_f
			"-=":
				new_value = current_f - delta_f
			"*=":
				new_value = current_f * delta_f
			"/=":
				if delta_f == 0.0:
					VNEngineLog.warn("CmdFlag", "Division by zero, no change made: %s" % args)
					return
				new_value = current_f / delta_f
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

func _literal(value_str: String) -> Variant:
	var text: String = value_str.strip_edges()
	if text.to_lower() == "true":
		return true
	if text.to_lower() == "false":
		return false
	if text.is_valid_float():
		return text.to_float()
	return text

func _to_float(value: Variant) -> float:
	if typeof(value) == TYPE_BOOL:
		return 1.0 if value else 0.0
	if typeof(value) == TYPE_STRING:
		var text: String = value
		if text.is_valid_float():
			return text.to_float()
		return 0.0
	return float(value)
