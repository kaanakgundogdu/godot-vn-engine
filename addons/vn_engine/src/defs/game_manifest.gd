@tool
class_name VNEngineGameManifest
extends Resource

@export_group("Identity")
## Unique id for this game, like "my_first_vn". Used to separate save
## files between games.
@export var game_id: String = ""
## Game version, like "0.1.0".
@export var version: String = "0.1.0"

@export_group("Flow")
## ChapterDef.id a new game starts on.
@export var first_chapter: String = ""
## Fallback ending id used when the story ends without @end.
@export var default_ending: String = ""
## Add one ChapterDef per chapter in the game.
@export var chapters: Array[VNEngineChapterDef] = []
## Add one EndingDef per ending in the game.
@export var endings: Array[VNEngineEndingDef] = []

@export_group("Content")
## Boot sequence played before the title screen. null means no
## splash/opening.
@export var boot: VNEngineBootDef
## All flag and counter definitions for this game.
@export var flags: VNEngineFlagList

## Credits screen definition.
@export var credits: VNEngineCreditsDef

@export_group("Screens")
## Title screen definition.
@export var title: VNEngineTitleScreenDef
## Extras screen definition. null means default extras behaviour.
@export var extras: VNEngineExtrasDef
## Engine UI behaviour tuning. null means default UI behaviour.
@export var ui: VNEngineUiDef


func get_boot() -> VNEngineBootDef:
	return boot if boot != null else VNEngineBootDef.new()

func has_boot_sequence() -> bool:
	return get_boot().has_sequence()

func get_extras() -> VNEngineExtrasDef:
	return extras if extras != null else VNEngineExtrasDef.new()

func get_ui() -> VNEngineUiDef:
	return ui if ui != null else VNEngineUiDef.new()

func find_chapter(id: String) -> VNEngineChapterDef:
	var key: String = id.to_lower()
	for chapter: VNEngineChapterDef in chapters:
		if chapter == null:
			continue
		if chapter.id.to_lower() == key:
			return chapter
	return null

func find_ending(id: String) -> VNEngineEndingDef:
	var key: String = id.to_lower()
	for ending: VNEngineEndingDef in endings:
		if ending == null:
			continue
		if ending.id.to_lower() == key:
			return ending
	return null
