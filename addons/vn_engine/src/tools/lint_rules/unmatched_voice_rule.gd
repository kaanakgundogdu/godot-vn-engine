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

	var voices_root: String = ""
	if ctx.asset_map != null:
		for entry: VNEngineAssetMapEntry in ctx.asset_map.entries:
			if entry != null and entry.kind == "voice":
				voices_root = entry.root
	if voices_root == "":
		return
	for file in ctx.walk_files(voices_root):
		var basename: String = file["basename"]
		if not basename.ends_with(".ogg"):
			continue
		var line_id: String = basename.substr(0, basename.length() - 4)
		if not line_ids.has(line_id):
			ctx.warn("`%s%s` -- '%s' matches no line id" % [voices_root, file["rel_path"], line_id])
