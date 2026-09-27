@tool
class_name VNEngineManifestReferenceRule
extends VNEngineAssetLintRule


func title() -> String:
	return "8. Manifest references"


func run(ctx: VNEngineAssetLintContext) -> void:
	var manifest: VNEngineGameManifest = ctx.manifest
	if manifest == null:
		ctx.info("GameManifest could not be loaded, rule skipped")
		return

	for chapter in manifest.chapters:
		if chapter == null:
			continue
		if chapter.script_path != "" and not FileAccess.file_exists(chapter.script_path):
			ctx.error("ChapterDef '%s': script_path '%s' does not exist on disk" % [chapter.id, chapter.script_path])
		if chapter.next_chapter != "" and manifest.find_chapter(chapter.next_chapter) == null:
			ctx.error("ChapterDef '%s': next_chapter '%s' matches no ChapterDef.id" % [chapter.id, chapter.next_chapter])
		for branch in chapter.branches:
			if branch != null and branch.chapter_id != "" and manifest.find_chapter(branch.chapter_id) == null:
				ctx.error("ChapterDef '%s': branch target '%s' matches no ChapterDef.id" % [chapter.id, branch.chapter_id])

	if manifest.first_chapter == "":
		ctx.error("GameManifest.first_chapter is empty")
	elif manifest.find_chapter(manifest.first_chapter) == null:
		ctx.error("GameManifest.first_chapter '%s' matches no ChapterDef.id" % manifest.first_chapter)

	if manifest.default_ending != "" and manifest.find_ending(manifest.default_ending) == null:
		ctx.error("GameManifest.default_ending '%s' matches no EndingDef.id" % manifest.default_ending)
