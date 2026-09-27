@tool
class_name VNEngineDuplicateIdRule
extends VNEngineAssetLintRule


func title() -> String:
	return "9. Duplicate ids"


func run(ctx: VNEngineAssetLintContext) -> void:
	var manifest: VNEngineGameManifest = ctx.manifest
	if manifest == null:
		ctx.info("GameManifest could not be loaded, rule skipped")
		return

	_check_duplicates(ctx, "ChapterDef", _chapter_ids(manifest))
	_check_duplicates(ctx, "EndingDef", _ending_ids(manifest))


func _chapter_ids(manifest: VNEngineGameManifest) -> Array[String]:
	var out: Array[String] = []
	for chapter in manifest.chapters:
		if chapter != null:
			out.append(chapter.id)
	return out


func _ending_ids(manifest: VNEngineGameManifest) -> Array[String]:
	var out: Array[String] = []
	for ending in manifest.endings:
		if ending != null:
			out.append(ending.id)
	return out


func _check_duplicates(ctx: VNEngineAssetLintContext, label: String, ids: Array[String]) -> void:
	var seen: Dictionary = {}
	for id in ids:
		var key: String = id.to_lower()
		if seen.has(key):
			ctx.error("Two %ss share the id '%s' (case-insensitive)" % [label, id])
		else:
			seen[key] = true
