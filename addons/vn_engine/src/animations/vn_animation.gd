class_name VNEngineAnimation
extends RefCounted

var id: String = ""


func play(_target: CanvasItem, _params: Dictionary) -> void:
	pass


static func parse_params(tokens: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for token in tokens:
		var separator: int = token.find("=")
		if separator == -1:
			continue
		var key: String = token.substr(0, separator)
		var raw: String = token.substr(separator + 1)
		if raw.length() >= 2 and raw.begins_with("\"") and raw.ends_with("\""):
			result[key] = raw.substr(1, raw.length() - 2)
		elif raw.is_valid_int():
			result[key] = raw.to_int()
		elif raw.is_valid_float():
			result[key] = raw.to_float()
		elif raw == "true":
			result[key] = true
		elif raw == "false":
			result[key] = false
		else:
			result[key] = raw
	return result
