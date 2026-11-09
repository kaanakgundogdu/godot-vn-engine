class_name VNEngineCmdGotoChapter
extends VNEngineCommand

func command_name() -> String:
	return "goto_chapter"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var parsed := VNEngineCmdEnd.split_options(args)
	var chapter_id: String = parsed.id
	if chapter_id == "":
		VNEngineLog.warn("CmdGotoChapter", "'@goto_chapter' expects a chapter id")
		ctx.runner._jumped = true
		return

	VNEngineMain.game().goto_chapter(chapter_id, parsed.transition)
	ctx.runner._jumped = true
