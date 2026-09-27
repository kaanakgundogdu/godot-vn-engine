@tool
class_name VNEngineCgChapterFolderRule
extends VNEngineAssetLintRule


func title() -> String:
	return "7. CG chapter folder layout"


func run(ctx: VNEngineAssetLintContext) -> void:
	var chapter_ids: Dictionary = {}
	if ctx.manifest != null:
		for chapter in ctx.manifest.chapters:
			if chapter != null and chapter.id != "":
				chapter_ids[chapter.id.to_lower()] = true
	else:
		ctx.info("GameManifest (%s) could not be loaded -- <chapter_id> match check skipped, only the 'no subfolder' check ran" % VNEnginePaths.manifest())

	for entry in ctx.asset_map.entries:
		if entry == null or entry.kind != "cg":
			continue

		for file in ctx.walk_files(entry.root):
			var rel_dir: String = file["rel_dir"]

			if rel_dir == "":
				ctx.warn("`%s%s` (cg) is directly under cg/, expected cg/<chapter_id>/<name>" % [entry.root, file["rel_path"]])
				continue

			if ctx.manifest == null:
				continue

			var chapter_segment: String = rel_dir.split("/", false)[0]
			if not chapter_ids.has(chapter_segment.to_lower()):
				ctx.warn("`%s%s` (cg) -- folder '%s' matches no ChapterDef.id in GameManifest.chapters" % [entry.root, file["rel_path"], chapter_segment])
