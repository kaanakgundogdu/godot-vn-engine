@tool
class_name VNEngineUnmatchedVoiceRule
extends VNEngineAssetLintRule


func title() -> String:
	return "6. Unidentified voice lines"


func run(ctx: VNEngineAssetLintContext) -> void:
	var line_ids: Dictionary = {}
	for story: VNEngineStoryScript in ctx.scripts:
		for node in story.nodes:
			if node.line_id != "":
				line_ids[node.line_id] = true
			for choice in node.choices:
				if choice.line_id != "":
					line_ids[choice.line_id] = true

	var voice_entry: VNEngineAssetMapEntry = null
	if ctx.asset_map != null:
		for entry: VNEngineAssetMapEntry in ctx.asset_map.entries:
			if entry != null and entry.kind == "voice":
				voice_entry = entry
	if voice_entry == null:
		return

	var languages: Array[String] = ["en"]
	if ctx.manifest != null:
		languages = [ctx.manifest.source_language]
		for code in ctx.manifest.languages:
			languages.append(code)

	var root: String = voice_entry.root
	for file in ctx.walk_files(root):
		var basename: String = file["basename"]
		var ext: String = "." + basename.get_extension()
		if not voice_entry.extensions.has(ext):
			continue
		var folders: PackedStringArray = String(file["rel_dir"]).trim_suffix("/").split("/", false)
		if folders.size() < 2:
			ctx.warn("`%s%s` -- not in a language folder, move it to `%s<language>/%s`" % [root, file["rel_path"], root, file["rel_path"]])
			continue
		if not languages.has(folders[0]):
			ctx.warn("`%s%s` -- '%s' is not a language of the game" % [root, file["rel_path"], folders[0]])
			continue
		var line_id: String = basename.get_basename()
		if not line_ids.has(line_id):
			ctx.warn("`%s%s` -- '%s' matches no line id" % [root, file["rel_path"], line_id])
