extends Resource
class_name VNEngineStoryNode


@export var id: String = ""
@export var line_id: String = ""
@export var line: int = 0
@export var speaker_id: String = ""
@export var expression: String = ""
@export var animation: String = ""
@export var text: String = ""
@export var commands: Array[Dictionary] = []
@export var choices: Array[VNEngineChoiceOption] = []
@export var next_index: int = -1
@export var is_terminal: bool = false

func is_pure_logic() -> bool:
	return text == "" and choices.is_empty()
