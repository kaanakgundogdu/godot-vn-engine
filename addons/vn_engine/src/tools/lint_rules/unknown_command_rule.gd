@tool
class_name VNEngineUnknownCommandRule
extends VNEngineAssetLintRule


func title() -> String:
	return "10. Unknown commands"


func run(ctx: VNEngineAssetLintContext) -> void:
	for path in ctx.scenario_paths:
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue

		var line_no := 0
		while not file.eof_reached():
			line_no += 1
			var line: String = file.get_line().replace("\r", "").strip_edges()
			if not line.begins_with("@"):
				continue

			var body: String = line.substr(1)
			var sp: int = body.find(" ")
			var cmd_name: String = (body.substr(0, sp) if sp != -1 else body).strip_edges()
			if cmd_name != "" and not VNEngineCommandRegistry.is_known(cmd_name):
				ctx.warn("`@%s` (%s line %d) is not a known command (CommandRegistry.is_known() returns false)" % [cmd_name, path, line_no])

		file.close()
