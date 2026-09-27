class_name VNEngineDiagnosticsScreen
extends VNEngineScreen


var _exit_to_title: bool = false

@onready var diagnostics_label: RichTextLabel = get_node_or_null("%DiagnosticsLabel") as RichTextLabel
@onready var source_label: Label = get_node_or_null("%SourceLabel") as Label
@onready var back_button: Button = get_node_or_null("%BackButton") as Button


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)


func screen_id() -> StringName:
	return &"diagnostics"


func enter(params: Dictionary) -> void:
	var diagnostics: Array = params.get("diagnostics", [])
	var source: String = params.get("source", "")
	_exit_to_title = bool(params.get("exit_to_title", false))

	source_label.text = source if source != "" else "(source not specified)"

	diagnostics_label.clear()

	if diagnostics.is_empty():
		diagnostics_label.append_text("[i]No diagnostics.[/i]")
		return

	for entry in diagnostics:
		var diag: VNEngineParseDiagnostic = entry as VNEngineParseDiagnostic
		if diag == null:
			continue
		diagnostics_label.append_text(_format_line(diag, source) + "\n")


func handle_back() -> bool:
	if _exit_to_title:
		VNEngineMain.game().return_to_title()
		return true
	VNEngineMain.instance().screen_stack.pop_screen()
	return true


func _on_back_pressed() -> void:
	handle_back()


func _format_line(diag: VNEngineParseDiagnostic, source: String) -> String:
	var color: String = "#aaaaaa"
	if diag.severity == VNEngineParseDiagnostic.Severity.ERROR:
		color = "#ff5555"
	elif diag.severity == VNEngineParseDiagnostic.Severity.WARNING:
		color = "#ffcc44"

	var file_part: String = source.get_file() if source != "" else "?"
	var line_text: String = "%s · %s:%d · %s" % [_severity_label(diag.severity), file_part, diag.line, diag.message]
	if diag.hint != "":
		line_text += " (%s)" % diag.hint

	return "[color=%s]%s[/color]" % [color, line_text]


func _severity_label(severity: int) -> String:
	match severity:
		VNEngineParseDiagnostic.Severity.ERROR:
			return "ERROR"
		VNEngineParseDiagnostic.Severity.WARNING:
			return "WARNING"
		_:
			return "INFO"
