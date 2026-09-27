extends RefCounted
class_name VNEngineScenarioLinter


const _SET_VAR_OPS := ["=", "+=", "-=", "*=", "/="]
const _FLOW_STOP_COMMANDS := ["jump", "call", "return", "end", "goto_chapter"]


static func _is_zero_literal(value_str: String) -> bool:
	var trimmed: String = value_str.strip_edges()
	if not trimmed.is_valid_float():
		return false
	return trimmed.to_float() == 0.0


static func _lint_after_flow_stop(node: VNEngineStoryNode, script: VNEngineStoryScript) -> void:
	var stop_name: String = ""
	for cmd in node.commands:
		var cname: String = cmd.get("name", "")
		if stop_name != "" and VNEngineStoryRunner.DEFERRED_COMMANDS.has(cname):
			script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.WARNING, cmd["line"], "'@%s' never runs, it comes after '@%s' in the same node" % [cname, stop_name]))
		elif stop_name == "" and _FLOW_STOP_COMMANDS.has(cname):
			stop_name = cname


static func lint(script: VNEngineStoryScript) -> void:
	var reachable: Dictionary = {}

	for node in script.nodes:
		for choice in node.choices:
			choice.target_index = script.index_of(choice.target)
			if choice.target_index == -1:
				script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, choice.line, "Choice target not found: '%s'" % choice.target))
			else:
				reachable[choice.target_index] = true

		if node.choices.size() > 0:
			for cmd in node.commands:
				if cmd.get("name", "") == "jump":
					script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.WARNING, cmd["line"], "'@jump' is ignored when choices are present"))

		_lint_after_flow_stop(node, script)

		for cmd in node.commands:
			_lint_command(cmd, script, reachable)

	_lint_show_before_speak(script)

	for i in range(1, script.nodes.size()):
		if not reachable.has(i) and script.nodes[i - 1].is_terminal:
			script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.WARNING, script.nodes[i].line, "This node is not targeted from anywhere and the previous node is terminal (unreachable)"))


static func lint_expressions(script: VNEngineStoryScript) -> void:
	for node in script.nodes:
		for cmd in node.commands:
			if cmd.get("name", "") == "jump_if":
				var condition: String = _extract_jump_if_condition(cmd.get("args", ""))
				if condition != "":
					_validate_expression(condition, cmd.get("line", 0), script)
		for choice in node.choices:
			if choice.condition != "":
				_validate_expression(choice.condition, choice.line, script)
			if choice.disabled_if != "":
				_validate_expression(choice.disabled_if, choice.line, script)


static func lint_flags(script: VNEngineStoryScript, flag_list: VNEngineFlagList) -> void:
	for node in script.nodes:
		for cmd in node.commands:
			var cname: String = cmd.get("name", "")
			if cname == "flag" or cname == "set_var":
				var cmd_args: String = cmd.get("args", "")
				var tokens: PackedStringArray = cmd_args.split(" ", false)
				if tokens.size() >= 1:
					_check_flag_id(tokens[0], cmd.get("line", 0), script, flag_list)
			elif cname == "jump_if":
				var condition: String = _extract_jump_if_condition(cmd.get("args", ""))
				if condition != "":
					_lint_expression_flags(condition, cmd.get("line", 0), script, flag_list)

		for choice in node.choices:
			if choice.condition != "":
				_lint_expression_flags(choice.condition, choice.line, script, flag_list)
			if choice.disabled_if != "":
				_lint_expression_flags(choice.disabled_if, choice.line, script, flag_list)


static func _lint_command(cmd: Dictionary, script: VNEngineStoryScript, reachable: Dictionary) -> void:
	var name: String = cmd.get("name", "")
	var args: String = cmd.get("args", "")
	var line_no: int = cmd.get("line", 0)

	if not VNEngineCommandRegistry.is_known(name):
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.WARNING, line_no, "Unknown command: '@%s'" % name, _suggest(name)))
		return

	match name:
		"jump":
			if args == "":
				script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@jump' expects a target"))
			else:
				var idx: int = script.index_of(args)
				if idx == -1:
					script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@jump' target not found: '%s'" % args))
				else:
					reachable[idx] = true
		"jump_if":
			_lint_jump_if(args, line_no, script, reachable)
		"call":
			if args == "":
				script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@call' expects a target"))
			else:
				var call_idx: int = script.index_of(args)
				if call_idx == -1:
					script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@call' target not found: '%s'" % args))
				else:
					reachable[call_idx] = true
		"return":
			pass
		"scene":
			_lint_scene(args, line_no, script)
		"set_var":
			_lint_set_var(args, line_no, script)
		"flag":
			_lint_flag(args, line_no, script)
		"goto_chapter":
			_lint_goto_chapter(args, line_no, script)
		"show":
			if args == "":
				script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@show' expects a character id"))
		"hide", "leave":
			if args == "":
				script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@%s' expects a character id" % name))
		"move":
			if args == "":
				script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@move' expects a character id"))
		"movie":
			if args == "":
				script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@movie' expects a file name"))
		"music", "sfx", "voice":
			if args == "":
				script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@%s' expects an asset name" % name))
		"bg":
			if args == "":
				script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@bg' expects a background name"))
		"wait":
			if args == "" or not args.is_valid_float():
				script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@wait' expects a valid number of seconds"))
		"choice_timer":
			var ct_tokens: PackedStringArray = args.split(" ", false)
			if ct_tokens.is_empty() or not ct_tokens[0].is_valid_float() or ct_tokens[0].to_float() <= 0.0:
				script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@choice_timer' expects a valid number of seconds (>0)"))
			elif ct_tokens.size() > 1 and (not ct_tokens[1].is_valid_int() or ct_tokens[1].to_int() < 0):
				script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.WARNING, line_no, "'@choice_timer' default_index must be an integer >= 0: '%s'" % ct_tokens[1]))
		"shake", "end":
			pass


static func _lint_jump_if(args: String, line_no: int, script: VNEngineStoryScript, reachable: Dictionary) -> void:
	if not args.contains("->"):
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@jump_if' expects '<condition> -> <target>'"))
		return

	var parts: PackedStringArray = args.split("->", true, 1)
	var condition: String = parts[0].strip_edges()
	var target: String = parts[1].strip_edges()

	if condition == "":
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@jump_if' has an empty expression"))

	if target == "":
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@jump_if' expects a target"))
		return

	var idx: int = script.index_of(target)
	if idx == -1:
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@jump_if' target not found: '%s'" % target))
	else:
		reachable[idx] = true


static func _lint_scene(args: String, line_no: int, script: VNEngineStoryScript) -> void:
	if args == "":
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@scene' expects a file path"))
		return

	var tokens: PackedStringArray = args.split(" ", false)
	var file_arg: String = tokens[0]
	if file_arg.begins_with("res://") and not ResourceLoader.exists(file_arg):
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.WARNING, line_no, "Scene file not found: '%s'" % file_arg))


static func _lint_set_var(args: String, line_no: int, script: VNEngineStoryScript) -> void:
	var tokens: PackedStringArray = args.split(" ", false)
	if tokens.size() < 3:
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@set_var' expects <name> <op> <value>"))
		return

	var var_name: String = tokens[0]
	var op: String = tokens[1]
	var value_str: String = " ".join(tokens.slice(2))

	if not var_name.is_valid_identifier():
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.WARNING, line_no, "Invalid variable name: '%s'" % var_name))

	if not _SET_VAR_OPS.has(op):
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "Unknown operator: '%s'" % op))
	elif op == "/=" and _is_zero_literal(value_str):
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.WARNING, line_no, "Division by zero, the operation will not run"))


static func _lint_flag(args: String, line_no: int, script: VNEngineStoryScript) -> void:
	var tokens: PackedStringArray = args.split(" ", false)
	if tokens.size() < 3:
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@flag' expects <name> <op> <value>"))
		return

	var flag_name: String = tokens[0]
	var op: String = tokens[1]
	var value_str: String = " ".join(tokens.slice(2))

	if not flag_name.is_valid_identifier():
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.WARNING, line_no, "Invalid flag name: '%s'" % flag_name))

	if not _SET_VAR_OPS.has(op):
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "Unknown operator: '%s'" % op))
	elif op == "/=" and _is_zero_literal(value_str):
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.WARNING, line_no, "Division by zero, the operation will not run"))


static func _lint_goto_chapter(args: String, line_no: int, script: VNEngineStoryScript) -> void:
	var trimmed: String = args.strip_edges()
	if trimmed == "":
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'@goto_chapter' expects a chapter id"))
		return
	if trimmed.split(" ", false).size() > 1:
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.WARNING, line_no, "'@goto_chapter' expects a single chapter id: '%s'" % trimmed))


static func _lint_show_before_speak(script: VNEngineStoryScript) -> void:
	var shown: Dictionary = {}
	var warned: Dictionary = {}

	for node in script.nodes:
		for cmd in node.commands:
			var cname: String = cmd.get("name", "")
			var cargs: String = cmd.get("args", "")
			if cname == "show":
				var show_tokens: PackedStringArray = cargs.split(" ", false)
				if show_tokens.size() > 0:
					shown[show_tokens[0].to_lower()] = true
			elif cname == "hide" or cname == "leave":
				var hide_tokens: PackedStringArray = cargs.split(" ", false)
				if hide_tokens.size() > 0:
					shown.erase(hide_tokens[0].to_lower())

		if node.speaker_id != "" and node.speaker_id != "narrator" and not shown.has(node.speaker_id) and not warned.has(node.speaker_id):
			script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.INFO, node.line, "'%s' speaks with no sprite on screen" % node.speaker_id))
			warned[node.speaker_id] = true


static func _suggest(name: String) -> String:
	for known in VNEngineCommandRegistry.known_names():
		if name.begins_with(known) or known.begins_with(name):
			return "suggestion: '@%s'" % known
	return ""


static func _extract_jump_if_condition(args: String) -> String:
	if not args.contains("->"):
		return ""
	return args.split("->", true, 1)[0].strip_edges()


static func _validate_expression(expr: String, line_no: int, script: VNEngineStoryScript) -> void:
	for msg in VNEngineExpressionEvaluator.validate(expr):
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, msg))


static func _check_flag_id(id: String, line_no: int, script: VNEngineStoryScript, flag_list: VNEngineFlagList) -> void:
	if id == "":
		return
	if not flag_list.has_flag(id):
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.WARNING, line_no, "Undefined flag: '%s'" % id.to_lower(), _suggest_flag(id, flag_list)))


static func _lint_expression_flags(expr: String, line_no: int, script: VNEngineStoryScript, flag_list: VNEngineFlagList) -> void:
	for id in VNEngineExpressionEvaluator.collect_identifiers(expr):
		_check_flag_id(id, line_no, script, flag_list)

	var base_errors: PackedStringArray = VNEngineExpressionEvaluator.validate(expr)
	for msg in VNEngineExpressionEvaluator.validate(expr, flag_list):
		if base_errors.has(msg):
			continue
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, msg))


static func _suggest_flag(id: String, flag_list: VNEngineFlagList) -> String:
	var lowered: String = id.to_lower()
	for known in flag_list.ids():
		if lowered.begins_with(known) or known.begins_with(lowered):
			return "similar flag: '%s'" % known
	return ""
