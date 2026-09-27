extends Resource
class_name VNEngineParseDiagnostic


enum Severity { ERROR, WARNING, INFO }

const ERROR := Severity.ERROR
const WARNING := Severity.WARNING
const INFO := Severity.INFO

@export var severity: Severity = Severity.WARNING
@export var line: int = 0
@export var message: String = ""
@export var hint: String = ""

func _init(p_severity: Severity = Severity.WARNING, p_line: int = 0, p_message: String = "", p_hint: String = "") -> void:
	severity = p_severity
	line = p_line
	message = p_message
	hint = p_hint

func _severity_name() -> String:
	match severity:
		Severity.ERROR:
			return "ERROR"
		Severity.WARNING:
			return "WARNING"
		_:
			return "INFO"

func format() -> String:
	var text: String = "[%s] Line %d: %s" % [_severity_name(), line, message]
	if hint != "":
		text += " (%s)" % hint
	return text
