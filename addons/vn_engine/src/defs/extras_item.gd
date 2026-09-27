@tool
class_name VNEngineExtrasItem
extends Resource

## Asset id, like "cg_cottage_fire_01".
@export var id: String = ""
## Display name shown in the extras gallery. Empty means show the id.
@export var title: String = ""
## Optional res:// image used as the card image, instead of the asset
## itself.
@export var thumbnail: String = ""
## If true, this entry is not listed at all while locked.
@export var hidden_until_unlocked: bool = false
## Locked look for this entry. "default" uses ExtrasDef.locked_style.
@export_enum("default", "placeholder", "blur", "image") var locked_style: String = "default"
## Overrides ExtrasDef.locked_text for this entry. Empty uses the default.
@export var locked_text: String = ""
