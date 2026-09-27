@tool
class_name VNEngineFlagDef
extends Resource

## Flag id, like "affection_hana". Should be lowercase, the linter
## warns otherwise.
@export var id: String = ""
## Value type. default_value is converted to this type by FlagList.coerce.
@export_enum("bool", "int", "string") var type: String = "int"
## Default value, written as text. Converted to the right type by
## FlagList.coerce.
@export var default_value: String = "0"
## "playthrough" lives in the save, is part of rollback, and resets on
## a new game. "global" persists across playthroughs until deleted.
@export_enum("playthrough", "global") var scope: String = "playthrough"
## Lower clamp for int type flags.
@export var min_value: int = -999999
## Upper clamp for int type flags.
@export var max_value: int = 999999
## Shown in the dev overlay (F3) instead of the flag id, when set. Empty
## means show the flag id.
@export var debug_name: String = ""
