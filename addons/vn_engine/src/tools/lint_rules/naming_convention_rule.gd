@tool
class_name VNEngineNamingConventionRule
extends VNEngineAssetLintRule


func title() -> String:
	return "1. Naming violations"


func run(ctx: VNEngineAssetLintContext) -> void:
	var kind_regex: Dictionary = {
		"background": ctx.rx_bg,
		"cg": ctx.rx_cg,
		"character": ctx.rx_character,
		"music": ctx.rx_music,
		"sfx": ctx.rx_sfx,
		"ui": ctx.rx_ui,
		"movie": ctx.rx_movie,
	}

	for entry in ctx.asset_map.entries:
		if entry == null or not kind_regex.has(entry.kind):
			continue

		var rx: RegEx = kind_regex[entry.kind]
		var root: String = entry.root

		for file in ctx.walk_files(root):
			var basename: String = file["basename"]

			if rx.search(basename) == null:
				ctx.error("`%s%s` (%s) does not match the naming pattern for its kind" % [root, file["rel_path"], entry.kind])
				continue

			if entry.kind == "character":
				var rel_dir: String = file["rel_dir"]
				if rel_dir == "":
					ctx.error("`%s%s` (character) is directly under characters/ with no <char_id>/ subfolder" % [root, file["rel_path"]])
				else:
					var char_folder: String = rel_dir.rstrip("/")
					var expected_prefix: String = char_folder + "_"
					if not basename.begins_with(expected_prefix):
						ctx.error("`%s%s` (character) does not start with its folder's id (expected prefix '%s')" % [root, file["rel_path"], expected_prefix])
