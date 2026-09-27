@tool
class_name VNEngineCast
extends Resource

## One entry per character. Add one CastMember per character in the game.
@export var characters: Array[VNEngineCastMember] = []


func get_entry(id: String) -> VNEngineCastMember:
	var key: String = id.to_lower()
	for entry: VNEngineCastMember in characters:
		if entry == null:
			continue
		if entry.id.to_lower() == key:
			return entry
	return null


func is_narrator(id: String) -> bool:
	var key: String = id.to_lower()
	if key == "narrator":
		return true

	var entry: VNEngineCastMember = get_entry(key)
	if entry == null:
		return true

	return entry.is_narrator


func display_name_of(id: String) -> String:
	if id == "":
		return ""

	var entry: VNEngineCastMember = get_entry(id)
	if entry != null and entry.display_name != "":
		return entry.display_name

	return id.capitalize().to_upper()
