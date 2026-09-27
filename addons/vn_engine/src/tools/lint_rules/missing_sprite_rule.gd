@tool
class_name VNEngineMissingSpriteRule
extends VNEngineAssetLintRule


func title() -> String:
	return "11. Missing sprites"


func run(ctx: VNEngineAssetLintContext) -> void:
	for ref in ctx.refs.get("character", []):
		var path: String = ctx.resolver.resolve_character(ref["char_id"], ref["outfit"], ref["pose"], ref["expression"], ref["shot"])
		if path == "":
			var suffix: String = "%s_%s_%s_%s_%s.png" % [ref["char_id"], ref["outfit"], ref["pose"], ref["expression"], ref["shot"]]
			ctx.error("`%s` (character) is referenced by %s line %d but does not exist on disk" % [suffix, ref["source"], ref["line"]])
