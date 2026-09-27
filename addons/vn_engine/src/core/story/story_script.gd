extends Resource
class_name VNEngineStoryScript


@export var source_path: String = ""
@export var chapter_id: String = ""
@export var nodes: Array[VNEngineStoryNode] = []
@export var labels: Dictionary = {}
@export var diagnostics: Array[VNEngineParseDiagnostic] = []

func has_errors() -> bool:
	for diag in diagnostics:
		if diag.severity == VNEngineParseDiagnostic.Severity.ERROR:
			return true
	return false

func index_of(target: String) -> int:
	if labels.has(target):
		return labels[target]
	return -1
