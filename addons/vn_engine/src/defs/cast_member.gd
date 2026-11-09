class_name VNEngineCastMember
extends Resource

@export_group("Identity")
## Character id used in scripts, like "hana". Must be unique.
@export var id: String = ""
## Display name shown in dialog, like "Hana".
@export var display_name: String = ""
## If true, this character's lines skip name display and count as narration.
@export var is_narrator: bool = false
## Color used for this character's name in the dialog box.
@export var name_color: Color = Color.WHITE

@export_group("Default sprite")
## Default outfit id, like "casual". Used when a line does not set one.
@export var default_outfit: String = ""
## Default pose id, like "armscrossed" or "base". Used when a line does
## not set one.
@export var default_pose: String = ""
## Default facial expression only, like "normal". Outfit, pose, and shot
## are separate fields.
@export var default_expression: String = ""
## Camera distance used when a line does not set one.
@export_enum("far", "mid", "close") var default_shot: String = "mid"
## Size multiplier for this character's sprites. 1.0 fits a 760x1000 box
## (almost full screen height). Use it when the art is drawn bigger or smaller.
@export_range(0.25, 2.0, 0.05) var sprite_scale: float = 1.0

@export_group("Side image")
## If true, the dialog box shows this character's side image (a small portrait
## on the left) while they speak. It needs a "side" entry in the asset map.
@export var side_image: bool = true

@export_group("Text blips")
## "auto" blips for normal characters and stays silent for narrators. "on"
## always blips, "off" never does.
@export_enum("auto", "on", "off") var blip: String = "auto"
## Pitch of this character's blips. Higher sounds lighter, lower sounds
## heavier.
@export_range(0.5, 2.0, 0.05) var blip_pitch: float = 1.0
## Blip sound for this character. Empty uses the game's blip sound.
@export var blip_sound: AudioStream
