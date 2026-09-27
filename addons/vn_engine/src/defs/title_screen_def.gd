@tool
class_name VNEngineTitleScreenDef
extends Resource

@export_group("Normal")
## Background asset id for the normal title screen.
@export var background: String = ""
## Music asset id played on the title screen.
@export var bgm: String = "bgm_title"
## res:// path or a "background"/"cg" asset id. Empty means no logo.
@export var logo: String = ""
## Horizontal alignment of the title screen menu buttons.
@export_enum("left", "center", "right") var menu_alignment: String = "center"

@export_group("Cleared")
## Background asset id used once the game has been cleared at least
## once. Empty keeps using background.
@export var cleared_background: String = ""
## Music asset id for the cleared title screen. Empty means keep using bgm.
@export var cleared_bgm: String = ""

@export_group("Menu visibility")
## When the Extras button shows. "" always shows it, "cleared_once"
## needs the game cleared at least once, "never" always hides it.
## Anything else is treated as a global-flag expression.
@export var show_extras_when: String = ""
## When the Chapter Select button shows. Same values as show_extras_when.
@export var show_chapter_select_when: String = "cleared_once"
## If true, debug builds always show Chapter Select, as a testing aid.
@export var chapter_select_in_debug: bool = true
