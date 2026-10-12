@tool
class_name VNEngineBootScreenDef
extends Resource

## Set to false to skip this step without deleting it.
@export var enabled: bool = true
## Image shown for this step. Ignored when movie_path is also set.
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp", "*.svg") var image_path: String = ""

## Video shown for this step. Wins over image_path when both are set.
@export_file("*.ogv") var movie_path: String = ""
## Text shown centered on the backdrop when image_path and movie_path are empty.
@export_multiline var text: String = ""
## Image and text screens only. Seconds this screen stays up, fades included.
@export var duration: float = 2.5
## Image and text screens only. Fade in and fade out time in seconds.
@export var fade_time: float = 0.5
## Image and text screens only. If true, waits for a click or key instead of the
## timer. duration is ignored when this is on.
@export var wait_for_input: bool = false
## Backdrop color behind the image, video or text.
@export var background_color: Color = Color.BLACK
## A click or key skips this screen. Ignored when wait_for_input is on.
@export var skippable: bool = true
