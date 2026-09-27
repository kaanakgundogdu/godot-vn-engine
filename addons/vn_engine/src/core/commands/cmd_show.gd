class_name VNEngineCmdShow
extends VNEngineCommand

func command_name() -> String:
	return "show"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var parsed: Dictionary = parse_show_args(args)
	if parsed.is_empty():
		VNEngineLog.warn("CmdShow", "Missing argument: '@show' expects a character id")
		return

	var id: String = parsed["id"]
	var expression: String = parsed["expression"]
	var outfit: String = parsed["outfit"]
	var pose: String = parsed["pose"]
	var shot: String = parsed["shot"]
	var position: String = parsed["position"]
	var transition: String = parsed["transition"]

	var entry: VNEngineCastMember = null
	if ctx.characters and ctx.characters.cast:
		entry = ctx.characters.cast.get_entry(id)

	if expression == "" and entry:
		expression = entry.default_expression
	if outfit == "" and entry:
		outfit = entry.default_outfit
	if pose == "" and entry:
		pose = entry.default_pose
	if shot == "" and entry:
		shot = entry.default_shot

	if position == "":
		position = "center"
	if transition == "":
		transition = "fade"

	ctx.state.characters[id] = {"expression": expression, "position": position, "outfit": outfit, "pose": pose, "shot": shot}

	if ctx.characters:
		ctx.characters.show_character(id, outfit, pose, expression, shot, position, transition)


static func parse_show_args(args: String) -> Dictionary:
	var tokens: PackedStringArray = args.strip_edges().split(" ", false)
	if tokens.is_empty():
		return {}

	var id: String = tokens[0].to_lower()
	var expression := ""
	var outfit := ""
	var pose := ""
	var shot := ""
	var position := ""
	var transition := ""

	var i := 1
	if i < tokens.size() and tokens[i] != "at" and tokens[i] != "with" and not tokens[i].contains("="):
		expression = tokens[i]
		i += 1

	while i < tokens.size():
		if tokens[i] == "at" and i + 1 < tokens.size():
			position = tokens[i + 1]
			i += 2
		elif tokens[i] == "with" and i + 1 < tokens.size():
			transition = tokens[i + 1]
			i += 2
		elif tokens[i].begins_with("outfit="):
			outfit = tokens[i].substr(7)
			i += 1
		elif tokens[i].begins_with("pose="):
			pose = tokens[i].substr(5)
			i += 1
		elif tokens[i].begins_with("shot="):
			shot = tokens[i].substr(5)
			i += 1
		else:
			i += 1

	return {"id": id, "expression": expression, "outfit": outfit, "pose": pose, "shot": shot, "position": position, "transition": transition}
