@tool
extends EditorScript


const CONTENT_ROOT := "res://addons/vn_engine/sample_game/"
const REPORT_DIR := "res://vn_engine_reports/"
const REPORT_FILENAME := "asset_lint_report.md"


func _run() -> void:
	VNEnginePaths.set_content_root(CONTENT_ROOT)
	var ctx := VNEngineAssetLintContext.new()
	if not ctx.setup():
		return

	var rules: Array[VNEngineAssetLintRule] = [
		VNEngineNamingConventionRule.new(),
		VNEngineOrphanAssetRule.new(),
		VNEngineMissingAssetRule.new(),
		VNEngineCgBackgroundMixupRule.new(),
		VNEngineSpriteMatrixGapRule.new(),
		VNEngineUnmatchedVoiceRule.new(),
		VNEngineCgChapterFolderRule.new(),
		VNEngineManifestReferenceRule.new(),
		VNEngineDuplicateIdRule.new(),
		VNEngineUnknownCommandRule.new(),
		VNEngineMissingSpriteRule.new(),
	]

	var sections: Array[String] = []
	for rule in rules:
		ctx.reset_section()
		rule.run(ctx)
		sections.append(ctx.build_section(rule.title()))

	_write_report(sections, ctx.scenario_paths.size())


func _report_path() -> String:
	return REPORT_DIR + REPORT_FILENAME


func _write_report(sections: Array[String], scenario_file_count: int) -> void:
	var body := "# Asset Lint Report (AssetLinter)\n\n"
	body += "Generated: %s\n\n" % Time.get_datetime_string_from_system()
	body += "Scanned scenario files: %d.\n\n" % scenario_file_count

	var full_body := ""
	for section_text in sections:
		full_body += section_text

	var error_count: int = full_body.count("[ERROR]")
	var warning_count: int = full_body.count("[WARNING]")

	body += "**Summary:** %d ERROR, %d WARNING.\n\n" % [error_count, warning_count]
	body += "---\n\n"
	body += full_body
	body += "---\n"

	var path: String = _report_path()
	var report_dir: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(report_dir):
		DirAccess.make_dir_recursive_absolute(report_dir)

	var report_file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if report_file == null:
		VNEngineLog.error("AssetLinter", "Could not write report: %s (error code %d)" % [path, FileAccess.get_open_error()])
		return
	report_file.store_string(body)
	report_file.close()

	if path.begins_with("res://"):
		var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
		if fs:
			fs.scan()

	VNEngineLog.info("AssetLinter", "Report written: %s" % path)
	VNEngineLog.info("AssetLinter", "Summary: %d ERROR, %d WARNING" % [error_count, warning_count])
