class_name VNEngineCmdGotoChapter
extends VNEngineCommand

func command_name() -> String:
	return "goto_chapter"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var chapter_id: String = args.strip_edges()
	if chapter_id == "":
		VNEngineLog.warn("CmdGotoChapter", "'@goto_chapter' expects a chapter id")
		ctx.runner._jumped = true
		return

	VNEngineMain.game().goto_chapter(chapter_id)
	ctx.runner._jumped = true
