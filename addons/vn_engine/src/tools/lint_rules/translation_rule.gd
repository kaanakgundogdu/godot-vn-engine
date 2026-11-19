@tool
class_name VNEngineTranslationRule
extends VNEngineAssetLintRule

const LISTED := 10


func title() -> String:
	return "13. Translations"


func run(ctx: VNEngineAssetLintContext) -> void:
	if ctx.manifest == null:
		return
	var languages: Array[String] = []
	for code in ctx.manifest.languages:
		if code != "" and code != ctx.manifest.source_language:
			languages.append(code)
	if languages.is_empty():
		ctx.info("No translation languages in game.tres.")
		return

	var root: String = VNEnginePaths.content_root()
	var expected: Array[PackedStringArray] = VNEngineTranslationBuilder.collect(root, ctx.manifest)
	for code in languages:
		var file_name: String = code + ".csv"
		var path: String = root + VNEngineLocale.FOLDER + file_name
		if not FileAccess.file_exists(path):
			ctx.warn("`%s` -- '%s' has no file, run Project > Tools > VN Engine: Update translations" % [path, code])
			continue
		var rows: Dictionary = VNEngineTranslationBuilder.read_rows(path)
		var outdated: Array[String] = []
		var empty: Array[String] = []
		for row in expected:
			var key: String = VNEngineTranslationBuilder.row_key(row[0], row[1])
			if not rows.has(key) or rows[key][1] != row[1]:
				outdated.append(_label(row[0], row[1]))
			elif rows[key][2] == "":
				empty.append(_label(row[0], row[1]))
		if not outdated.is_empty():
			ctx.warn("`%s` -- %d rows are missing or out of date (%s), run Project > Tools > VN Engine: Update translations" % [file_name, outdated.size(), _list(outdated)])
		if not empty.is_empty():
			ctx.warn("`%s` -- %d empty cells (%s)" % [file_name, empty.size(), _list(empty)])
		for key: String in rows:
			var cells: PackedStringArray = rows[key]
			match cells[3]:
				VNEngineTranslationBuilder.CHANGED:
					ctx.warn("`%s` -- %s is 'changed', the source text changed after it was translated" % [file_name, _label(cells[0], cells[1])])
				VNEngineTranslationBuilder.UNUSED:
					ctx.warn("`%s` -- %s is 'unused', it is no longer in the game" % [file_name, _label(cells[0], cells[1])])


func _label(id: String, text: String) -> String:
	return "ui '%s'" % text if id == VNEngineLocale.UI_ID else id


func _list(labels: Array[String]) -> String:
	var shown: String = ", ".join(labels.slice(0, LISTED))
	if labels.size() > LISTED:
		shown += ", ... +%d" % (labels.size() - LISTED)
	return shown
