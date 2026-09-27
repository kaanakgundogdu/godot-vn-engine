@tool
class_name VNEngineMissingAssetRule
extends VNEngineAssetLintRule


func title() -> String:
	return "3. Missing assets"


func run(ctx: VNEngineAssetLintContext) -> void:
	for kind in ["background", "cg", "music", "sfx", "movie"]:
		for ref in ctx.refs.get(kind, []):
			var name: String = ref["name"]
			if not ctx.resolver.exists(kind, name):
				ctx.error("`%s` (%s) is referenced by %s line %d but does not exist on disk" % [name, kind, ref["source"], ref["line"]])
