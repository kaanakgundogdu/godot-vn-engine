@tool
class_name VNEngineSpriteMatrixGapRule
extends VNEngineAssetLintRule


func title() -> String:
	return "5. Sprite matrix gaps"


func run(ctx: VNEngineAssetLintContext) -> void:
	if ctx.cast == null:
		ctx.info("characters.tres could not be loaded, rule skipped")
		return

	var disk_ids: Array[String] = ctx.resolver.list_all("character")

	for entry in ctx.cast.characters:
		if entry == null or entry.is_narrator:
			continue
		if entry.default_outfit == "" and entry.default_pose == "" and entry.default_shot == "":
			continue

		var char_id: String = entry.id
		var prefix: String = char_id + "/" + char_id + "_"
		var expressions: Dictionary = {}

		for id in disk_ids:
			if not id.begins_with(prefix):
				continue
			var rest: String = id.substr(prefix.length())
			var parts: PackedStringArray = rest.split("_")
			if parts.size() != 4:
				continue
			var expr: String = parts[2]
			expressions[expr] = true

		var missing: Array[String] = []
		for expr_key in expressions.keys():
			missing.append(String(expr_key))
		missing.sort()
		for expr in missing:
			var found_path: String = ctx.resolver.resolve_character(char_id, entry.default_outfit, entry.default_pose, expr, entry.default_shot)
			if found_path == "":
				var expected: String = "%s_%s_%s_%s_%s.png" % [char_id, entry.default_outfit, entry.default_pose, expr, entry.default_shot]
				ctx.warn("`%s`: expression '%s' exists in another pose/outfit but not in the default combination (%s/%s/%s), expected: `%s`" % [char_id, expr, entry.default_outfit, entry.default_pose, entry.default_shot, expected])
