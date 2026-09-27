class_name VNEngineCmdWindow
extends VNEngineCommand

func command_name() -> String:
	return "window"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var mode := args.strip_edges().to_lower()

	if ctx.dialog_ui == null:
		VNEngineLog.warn("CmdWindow", "No DialogUI in scene, skipping")
		return

	match mode:
		"hide":
			if not ctx.dialog_ui.is_ui_hidden:
				ctx.dialog_ui.toggle_ui()
		"show":
			if ctx.dialog_ui.is_ui_hidden:
				ctx.dialog_ui.toggle_ui()
		_:
			VNEngineLog.warn("CmdWindow", "Unknown argument: '%s' (expected show|hide)" % mode)
