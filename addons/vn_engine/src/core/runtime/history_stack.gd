extends RefCounted
class_name VNEngineHistoryStack


const MAX_DEPTH := 50

var _entries: Array[Dictionary] = []
var _cursor: int = -1

func push(snapshot: Dictionary, history_len: int) -> void:
	if _cursor < _entries.size() - 1:
		_entries.resize(_cursor + 1)

	_entries.append({"snapshot": snapshot, "history_len": history_len})

	if _entries.size() > MAX_DEPTH:
		_entries.pop_front()

	_cursor = _entries.size() - 1

func can_rollback() -> bool:
	return _cursor > 0

func rollback() -> Dictionary:
	_cursor -= 1
	return _entries[_cursor]

func can_forward() -> bool:
	return _cursor < _entries.size() - 1

func forward() -> Dictionary:
	_cursor += 1
	return _entries[_cursor]

func clear() -> void:
	_entries.clear()
	_cursor = -1

func shift_history(delta: int) -> void:
	for entry in _entries:
		var new_len: int = int(entry.get("history_len", 0)) + delta
		entry["history_len"] = maxi(new_len, 0)
