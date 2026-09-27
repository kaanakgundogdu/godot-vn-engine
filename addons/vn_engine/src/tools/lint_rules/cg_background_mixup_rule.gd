@tool
class_name VNEngineCgBackgroundMixupRule
extends VNEngineAssetLintRule


func title() -> String:
	return "4. CG/BG mixup"


func run(ctx: VNEngineAssetLintContext) -> void:
	for entry in ctx.asset_map.entries:
		if entry == null:
			continue

		for file in ctx.walk_files(entry.root):
			var basename: String = file["basename"]

			if entry.kind != "cg" and basename.begins_with("cg_"):
				ctx.error("`%s%s` (%s) has a 'cg_' prefix but is not under cg/" % [entry.root, file["rel_path"], entry.kind])

			if entry.kind != "background" and basename.begins_with("bg_"):
				ctx.error("`%s%s` (%s) has a 'bg_' prefix but is not under backgrounds/" % [entry.root, file["rel_path"], entry.kind])
