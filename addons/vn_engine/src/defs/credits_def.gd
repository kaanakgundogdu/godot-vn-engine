@tool
class_name VNEngineCreditsDef
extends Resource

@export_group("Content")
## Label for this credits variant, like "true_end". Informational only
## right now, since the manifest holds a single CreditsDef.
@export var variant: String = ""
## Add one CreditsSection per role row, in scroll order.
@export var sections: Array[VNEngineCreditsSection] = []

@export_group("Presentation")
## Scroll speed in pixels per second, used when movie is not set.
@export var scroll_speed: float = 60.0
## Music asset id played during credits.
@export var bgm: String = "bgm_credits"
## Background asset id behind the credits. Empty means none.
@export var background: String = ""
## Movie asset id played instead of scrolling text, when set.
@export var movie: String = ""
## If true, the player can skip the credits.
@export var allow_skip: bool = true
## Logo image shown after credits finish. Empty means none.
@export var end_logo: String = ""
