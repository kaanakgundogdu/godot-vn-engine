@tool
class_name VNEngineChapterBranch
extends Resource

## Boolean expression checked against flags, like "affection_hana >= 7
## and not saw_bad_ending". True means take this branch.
@export var condition: String = ""
## Chapter to go to if condition is true.
@export var chapter_id: String = ""
