@tool
class_name VNEngineChapterDef
extends Resource

@export_group("Identity")
## Must equal the folder name of script_path. Prefixes generated line_ids.
@export var id: String = ""
## Chapter title shown in the chapter-select screen and title cards.
@export var title: String = ""
## Chapter subtitle. Empty means no subtitle.
@export var subtitle: String = ""
## Path to this chapter's script file, example
## "res://<content>/scenario/chapter1/script.txt".
@export var script_path: String = ""

@export_group("Intro")
## How the chapter starts. "none" skips the intro, "card" shows a title
## card with intro_background, "eyecatch" shows intro_background full
## screen before the title.
@export_enum("none", "card", "eyecatch") var intro_style: String = "card"
## Background or cg asset id shown by intro_style "card" or "eyecatch".
@export var intro_background: String = ""
## Seconds the intro card or eyecatch stays on screen.
@export var intro_duration: float = 2.0
## Music asset id played on chapter start. Empty means leave the current
## music unchanged.
@export var bgm: String = ""

@export_group("Flow")
## If true, the game autosaves right when the player enters this chapter.
@export var autosave_on_enter: bool = true
## Chapter id to go to when no branch matches. Empty falls through to
## GameManifest.default_ending.
@export var next_chapter: String = ""
## Conditional branches, checked in order before next_chapter. The first
## one whose condition is true is taken.
@export var branches: Array[VNEngineChapterBranch] = []
## Flag expression for the chapter-select screen. Empty means always
## unlocked.
@export var unlock_condition: String = ""
