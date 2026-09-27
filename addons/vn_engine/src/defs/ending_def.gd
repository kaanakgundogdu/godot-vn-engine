@tool
class_name VNEngineEndingDef
extends Resource

@export_group("Identity")
## Ending id, like "true_end". Used by @end <id>.
@export var id: String = ""
## Ending title shown on the ending card and in the extras gallery.
@export var title: String = ""
## Ending rank shown in the extras gallery. Display only, does not
## affect which ending plays.
@export_enum("true", "good", "normal", "bad", "joke") var rank: String = "normal"
## Number shown in the gallery, like "END 03".
@export var number: int = 1
## If true, shows as "???" in extras until the player has seen this ending.
@export var is_secret: bool = false

@export_group("Selection")
## Flag expression checked when @end is called with no argument. The
## first ending in GameManifest.endings whose condition is true plays.
@export var condition: String = ""

@export_group("Presentation")
## Backdrop cg asset id for the ending card.
@export var cg: String = ""
## Music asset id played during the ending card.
@export var bgm: String = ""
## Seconds the ending card stays on screen. Ignored when ed_movie is set.
@export var card_duration: float = 3.0
## Empty plays the manifest's CreditsDef, "none" skips credits entirely.
## Any other value is only logged, since the manifest holds one CreditsDef.
@export var credits_variant: String = ""
## Movie asset id played for the ending theme, instead of the ending card.
@export var ed_movie: String = ""

@export_group("Unlocks")
## Global flags unlocked when this ending plays, like "true_route".
@export var unlocks: PackedStringArray = []
