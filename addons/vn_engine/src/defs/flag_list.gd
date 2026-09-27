@tool
class_name VNEngineFlagList
extends Resource

## All flag and counter definitions for this game. Add one FlagDef per
## flag.
@export var flags: Array[VNEngineFlagDef] = []

var _index: Dictionary = {}
var _index_built: bool = false


func rebuild_index() -> void:
	_index.clear()
	for flag: VNEngineFlagDef in flags:
		if flag == null:
			continue
		_index[flag.id.to_lower()] = flag
	_index_built = true


func find(id: String) -> VNEngineFlagDef:
	_ensure_index()
	var key: String = id.to_lower()
	if _index.has(key):
		var result: VNEngineFlagDef = _index[key]
		return result
	return null


func has_flag(id: String) -> bool:
	return find(id) != null


func ids() -> PackedStringArray:
	var result: PackedStringArray = []
	for flag: VNEngineFlagDef in flags:
		if flag == null:
			continue
		result.append(flag.id.to_lower())
	return result


func default_vars() -> Dictionary:
	var result: Dictionary = {}
	for flag: VNEngineFlagDef in flags:
		if flag == null or flag.scope != "playthrough":
			continue
		result[flag.id.to_lower()] = coerce(flag.id, flag.default_value)
	return result


func coerce(id: String, value: Variant) -> Variant:
	var flag: VNEngineFlagDef = find(id)
	if flag == null:
		return value

	match flag.type:
		"bool":
			if value is String:
				return value.to_lower() == "true"
			return bool(value)
		"int":
			var int_value: int = int(value)
			return clampi(int_value, flag.min_value, flag.max_value)
		"string":
			return str(value)
		_:
			return value


func _ensure_index() -> void:
	if not _index_built:
		rebuild_index()
