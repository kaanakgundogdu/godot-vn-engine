@tool
class_name VNEngineOrphanAssetRule
extends VNEngineAssetLintRule


func title() -> String:
	return "2. Orphan assets"


func run(ctx: VNEngineAssetLintContext) -> void:
	var kinds: Array[String] = ["background", "cg", "character", "music", "sfx", "movie"]

	var referenced: Dictionary = {}
	for simple_kind in ["background", "cg", "music", "sfx", "movie"]:
		var name_set: Dictionary = {}
		for ref in ctx.refs.get(simple_kind, []):
			name_set[ref["name"]] = true
		referenced[simple_kind] = name_set

	var char_set: Dictionary = {}
	for ref in ctx.refs.get("character", []):
		var full_id: String = "%s/%s_%s_%s_%s_%s" % [ref["char_id"], ref["char_id"], ref["outfit"], ref["pose"], ref["expression"], ref["shot"]]
		char_set[full_id] = true
	referenced["character"] = char_set

	for kind in kinds:
		if not ctx.kind_root_exists(kind):
			continue
		var disk_ids: Array[String] = ctx.resolver.list_all(kind)
		var ref_set: Dictionary = referenced.get(kind, {})
		for id in disk_ids:
			if not ref_set.has(id):
				ctx.warn("`%s` (%s) exists on disk but no scenario line references it" % [id, kind])
