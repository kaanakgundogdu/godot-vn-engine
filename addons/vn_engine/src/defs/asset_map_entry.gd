class_name VNEngineAssetMapEntry
extends Resource

## Which asset type this rule is for.
@export_enum("background", "character", "cg", "music", "sfx", "voice", "movie") var kind: String = "background"
## Folder this kind's files live in, like "res://<content>/backgrounds/".
@export var root: String = ""
## File extensions to try, in order, like [".png", ".webp"]. The first
## one that exists wins.
@export var extensions: Array[String] = []
