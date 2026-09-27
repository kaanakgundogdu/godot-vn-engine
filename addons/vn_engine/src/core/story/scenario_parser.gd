extends RefCounted
class_name VNEngineScenarioParser


static func parse_file(path: String, flag_list: VNEngineFlagList = null) -> VNEngineStoryScript:
	if not FileAccess.file_exists(path):
		var missing: VNEngineStoryScript = VNEngineStoryScript.new()
		missing.source_path = path
		missing.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, 0, "scenario file not found: %s (in exported games this usually means the VN Engine plugin was not enabled when exporting)" % path))
		return missing

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var unreadable: VNEngineStoryScript = VNEngineStoryScript.new()
		unreadable.source_path = path
		unreadable.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, 0, "Could not open file: %s (error code %d)" % [path, FileAccess.get_open_error()]))
		return unreadable

	var text: String = file.get_as_text()
	file.close()
	return parse_text(text, path, flag_list)

static func parse_text(text: String, source_name: String = "<memory>", flag_list: VNEngineFlagList = null) -> VNEngineStoryScript:
	var script: VNEngineStoryScript = VNEngineStoryScript.new()
	script.source_path = source_name

	var lines: PackedStringArray = text.split("\n")
	var current_node: VNEngineStoryNode = null
	var dialog_seen: Dictionary = {}

	for i in lines.size():
		var line_no: int = i + 1
		var line: String = String(lines[i]).replace("\r", "").strip_edges()

		if line == "":
			continue
		if line.begins_with("//"):
			continue

		if line.begins_with("#"):
			var node: VNEngineStoryNode = _parse_header(line, line_no, script)
			if node != null:
				current_node = node
			continue

		if current_node == null:
			script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "Content line before node header"))
			continue

		if line.begins_with("@"):
			_parse_command(line, line_no, current_node)
			continue

		if line.begins_with("-"):
			_parse_choice(line, line_no, current_node, script)
			continue

		if line.contains(":"):
			_parse_dialog(line, line_no, current_node, script, dialog_seen)
			continue

		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.WARNING, line_no, "Unrecognized line: '%s'" % line))

	_finalize_flow(script)
	VNEngineScenarioLinter.lint(script)
	VNEngineScenarioLinter.lint_expressions(script)
	if flag_list != null:
		VNEngineScenarioLinter.lint_flags(script, flag_list)
	_assign_line_ids(script)
	return script

static func _parse_header(line: String, line_no: int, script: VNEngineStoryScript) -> VNEngineStoryNode:
	var header: String = line.substr(1).strip_edges()
	var primary_label: String = ""
	var alias_label: String = ""
	var has_alias_separator: bool = false

	var body: String = header
	if header.begins_with("id:"):
		body = header.substr(3).strip_edges()

	if body.contains("|"):
		has_alias_separator = true
		var parts: PackedStringArray = body.split("|", true, 1)
		primary_label = parts[0].strip_edges()
		alias_label = (parts[1].strip_edges() if parts.size() > 1 else "")
	else:
		primary_label = body

	if primary_label == "":
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "Empty node header"))
		return null

	if primary_label.contains(" "):
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "Node id contains whitespace: '%s'" % primary_label))

	if has_alias_separator and alias_label == "":
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.WARNING, line_no, "Empty alias after '|', node will only have id '%s'" % primary_label))
	elif alias_label.contains(" "):
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "Node alias contains whitespace: '%s'" % alias_label))

	var node: VNEngineStoryNode = VNEngineStoryNode.new()
	node.line = line_no
	node.id = primary_label
	script.nodes.append(node)
	var idx: int = script.nodes.size() - 1

	_register_label(script, primary_label, idx, line_no)
	if alias_label != "":
		_register_label(script, alias_label, idx, line_no)

	return node

static func _register_label(script: VNEngineStoryScript, name: String, idx: int, line_no: int) -> void:
	if script.labels.has(name):
		var existing_idx: int = script.labels[name]
		if existing_idx != idx:
			var existing_line: int = script.nodes[existing_idx].line
			script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "'%s' is already defined at line %d" % [name, existing_line]))
		return
	script.labels[name] = idx

static func _parse_command(line: String, line_no: int, node: VNEngineStoryNode) -> void:
	var body: String = line.substr(1)
	var space_idx: int = body.find(" ")
	var cmd_name: String = ""
	var cmd_args: String = ""
	if space_idx == -1:
		cmd_name = body.strip_edges()
	else:
		cmd_name = body.substr(0, space_idx).strip_edges()
		cmd_args = body.substr(space_idx + 1).strip_edges()
	node.commands.append({"name": cmd_name, "args": cmd_args, "line": line_no})

static func _parse_choice(line: String, line_no: int, node: VNEngineStoryNode, script: VNEngineStoryScript) -> void:
	var body: String = line.substr(1).strip_edges()
	var arrow: int = body.find("->")
	if arrow == -1:
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "Choice is missing a '->' target"))
		return

	var choice_text: String = body.substr(0, arrow).strip_edges()
	var rest: String = body.substr(arrow + 2).strip_edges()

	if rest == "":
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "Choice target is empty"))
		return

	var target: String = ""
	var remainder: String = ""
	var space_idx: int = rest.find(" ")
	if space_idx == -1:
		target = rest
	else:
		target = rest.substr(0, space_idx)
		remainder = rest.substr(space_idx + 1).strip_edges()

	var condition: String = ""
	var disabled_if: String = ""
	var once: bool = false

	if remainder.begins_with("if "):
		remainder = remainder.substr(3)
		var condition_end: int = _find_next_keyword(remainder, ["disabled_if", "once"])
		if condition_end == -1:
			condition = remainder.strip_edges()
			remainder = ""
		else:
			condition = remainder.substr(0, condition_end).strip_edges()
			remainder = remainder.substr(condition_end).strip_edges()

	if remainder.begins_with("disabled_if "):
		remainder = remainder.substr(12)
		var disabled_if_end: int = _find_next_keyword(remainder, ["once"])
		if disabled_if_end == -1:
			disabled_if = remainder.strip_edges()
			remainder = ""
		else:
			disabled_if = remainder.substr(0, disabled_if_end).strip_edges()
			remainder = remainder.substr(disabled_if_end).strip_edges()

	if remainder == "once" or remainder.begins_with("once "):
		once = true
		remainder = remainder.substr(4).strip_edges()

	if remainder != "":
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.WARNING, line_no, "Choice modifiers could not be fully parsed: '%s'" % remainder))

	var choice: VNEngineChoiceOption = VNEngineChoiceOption.new()
	choice.text = choice_text
	choice.target = target
	choice.condition = condition
	choice.disabled_if = disabled_if
	choice.once = once
	choice.line = line_no
	node.choices.append(choice)

static func _find_next_keyword(text: String, keywords: Array) -> int:
	var best: int = -1
	for kw in keywords:
		var search_from: int = 0
		while true:
			var pos: int = text.find(" " + kw, search_from)
			if pos == -1:
				break
			var after: int = pos + 1 + kw.length()
			if after == text.length() or text[after] == " ":
				if best == -1 or pos < best:
					best = pos
				break
			search_from = pos + 1
	return best

static func _parse_dialog(line: String, line_no: int, node: VNEngineStoryNode, script: VNEngineStoryScript, dialog_seen: Dictionary) -> void:
	if dialog_seen.has(node):
		var first_line: int = dialog_seen[node]
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.ERROR, line_no, "This node already has dialog at line %d" % first_line))
		return

	var colon: int = line.find(":")
	var speaker_info: String = line.substr(0, colon).strip_edges()
	var text_part: String = line.substr(colon + 1).strip_edges()

	var parsed: Dictionary = _parse_speaker_info(speaker_info)
	var speaker_id: String = parsed["speaker_id"]

	if speaker_id == "" or speaker_id.contains(" "):
		script.diagnostics.append(VNEngineParseDiagnostic.new(VNEngineParseDiagnostic.Severity.WARNING, line_no, "Speaker section could not be parsed, the whole line is treated as narrator text"))
		node.speaker_id = "narrator"
		node.expression = ""
		node.animation = ""
		node.text = _unescape_text(line)
		dialog_seen[node] = line_no
		return

	node.speaker_id = speaker_id
	node.expression = parsed["expression"]
	node.animation = parsed["animation"]
	node.text = _unescape_text(text_part)
	dialog_seen[node] = line_no

static func _parse_speaker_info(info: String) -> Dictionary:
	var paren: Dictionary = _extract_bracketed(info, "(", ")")
	var brack: Dictionary = _extract_bracketed(info, "[", "]")

	var ranges: Array = []
	if paren["start"] != -1:
		ranges.append([paren["start"], paren["end"]])
	if brack["start"] != -1:
		ranges.append([brack["start"], brack["end"]])
	ranges.sort_custom(func(a, b): return a[0] > b[0])

	var speaker: String = info
	for bracket_range in ranges:
		speaker = speaker.substr(0, bracket_range[0]) + speaker.substr(bracket_range[1] + 1)

	return {
		"speaker_id": speaker.strip_edges().to_lower(),
		"expression": paren["value"],
		"animation": brack["value"],
	}

static func _extract_bracketed(text: String, open_ch: String, close_ch: String) -> Dictionary:
	var start: int = text.find(open_ch)
	if start == -1:
		return {"value": "", "start": -1, "end": -1}
	var end: int = text.find(close_ch, start)
	if end == -1:
		return {"value": "", "start": -1, "end": -1}
	return {"value": text.substr(start + 1, end - start - 1).strip_edges(), "start": start, "end": end}

static func _unescape_text(text: String) -> String:
	var placeholder: String = "__SCENARIO_BACKSLASH__"
	var result: String = text.replace("\\\\", placeholder)
	result = result.replace("\\n", "\n")
	result = result.replace(placeholder, "\\")
	return result

static func _finalize_flow(script: VNEngineStoryScript) -> void:
	var node_count: int = script.nodes.size()
	for i in node_count:
		var node: VNEngineStoryNode = script.nodes[i]
		node.next_index = (i + 1 if i + 1 < node_count else -1)

		var has_end: bool = false
		var has_unconditional_jump: bool = false
		for cmd in node.commands:
			var cname: String = cmd.get("name", "")
			if cname == "end":
				has_end = true
			elif cname == "jump":
				has_unconditional_jump = true

		node.is_terminal = (i == node_count - 1) or has_end or has_unconditional_jump or node.choices.size() > 0

static func _assign_line_ids(script: VNEngineStoryScript) -> void:
	var chapter_id: String = ""
	if script.source_path.begins_with("res://"):
		chapter_id = script.source_path.get_base_dir().get_file()
	script.chapter_id = chapter_id

	for node in script.nodes:
		node.line_id = (chapter_id + "." + node.id) if chapter_id != "" else node.id
		for i in node.choices.size():
			var choice: VNEngineChoiceOption = node.choices[i]
			choice.line_id = node.line_id + ".c" + str(i + 1)
