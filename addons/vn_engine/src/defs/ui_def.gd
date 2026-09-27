@tool
class_name VNEngineUiDef
extends Resource

@export_group("Overlays")
## Backdrop color behind settings, load and log panels.
@export var overlay_backdrop_color: Color = Color(0.02, 0.02, 0.04, 0.92)

@export_group("Confirmations")
## If true, asks the player to confirm before quitting the game.
@export var confirm_quit: bool = true
## If true, asks the player to confirm before overwriting an existing save.
@export var confirm_overwrite_save: bool = true
## If true, asks the player to confirm before going back to the title screen from the game menu.
@export var confirm_return_to_title: bool = true

@export_group("Dialog box")
## If true, the speaker name uses CastMember.name_color.
@export var dialog_use_character_colors: bool = true
## Name plate position above the dialog box.
@export_enum("left", "center") var dialog_name_align: String = "left"

@export_group("Loading screen")
## Loading screen shown between chapters and when loading a save.
## "always" always shows it, "when_slow" only when the load actually
## takes time, "never" skips it entirely.
@export_enum("always", "when_slow", "never") var loading_mode: String = "always"
## Minimum seconds the loading screen stays up, to avoid a flash. Real
## preload time decides the rest.
@export var loading_min_duration: float = 0.5
## Shows the next chapter's title and subtitle while loading. Skipped
## for chapters with their own intro card (ChapterDef.intro_style !=
## "none").
@export var loading_show_chapter_title: bool = true

@export_group("Log")
## If true, backlog speaker names use CastMember.name_color.
@export var log_use_character_colors: bool = true

@export_group("Custom scenes")
## Replaces built-in screens with your own scenes. Keys: title, stage,
## opening, credits, extras, chapter_select, diagnostics, loading. The
## scene root must extend VNScreen. Missing keys use the engine scene.
@export var screens: Dictionary[StringName, PackedScene] = {}
## Replaces built-in overlays with your own scenes. Keys: settings, load,
## gallery, log, confirm, game_menu. Keep the same methods and signals as
## the engine panel you replace.
@export var overlays: Dictionary[StringName, PackedScene] = {}
