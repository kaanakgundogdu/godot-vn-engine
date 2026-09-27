class_name VNEngineCmdScene
extends VNEngineCommand

func command_name() -> String:
	return "scene"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var tokens := args.split(" ", false)
	if tokens.is_empty():
		VNEngineLog.warn("CmdScene", "'@scene' expects a file path")
		return

	var file_path: String = tokens[0]
	var target: String = (tokens[1] if tokens.size() > 1 else "")

	if not ctx.runner._load_script(file_path):
		ctx.runner._jumped = true
		return

	var idx := 0
	if target != "":
		idx = ctx.script_res.index_of(target)
		if idx == -1:
			VNEngineLog.warn("CmdScene", "Target not found: '%s' (%s)" % [target, file_path])
			idx = 0

	ctx.runner.play_node(idx)
	ctx.runner._jumped = true
