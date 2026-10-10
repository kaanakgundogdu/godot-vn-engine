@tool
class_name VNEngineUnknownSpeakerRule
extends VNEngineAssetLintRule


const CHARACTER_COMMANDS: Array[String] = ["show", "hide", "move", "leave"]


func title() -> String:
	return "12. Unknown speakers"


func run(ctx: VNEngineAssetLintContext) -> void:
	if ctx.cast == null:
		return

	for i in ctx.scripts.size():
		var path: String = ctx.scenario_paths[i]
		var reported: Dictionary = {}
		for node in ctx.scripts[i].nodes:
			var speaker: String = node.speaker_id
			if speaker != "" and speaker != "narrator":
				_check(ctx, reported, speaker, path, node.line, "speaks")

			for cmd in node.commands:
				if not CHARACTER_COMMANDS.has(cmd.get("name", "")):
					continue
				var toks: PackedStringArray = String(cmd.get("args", "")).strip_edges().split(" ", false)
				if not toks.is_empty():
					_check(ctx, reported, toks[0].to_lower(), path, cmd.get("line", node.line), "is used in `@%s`" % cmd["name"])


func _check(ctx: VNEngineAssetLintContext, reported: Dictionary, id: String, path: String, line_no: int, usage: String) -> void:
	if reported.has(id) or ctx.cast.get_entry(id) != null:
		return
	reported[id] = true
	ctx.warn("`%s` %s at %s line %d but is not in the cast" % [id, usage, path, line_no])
