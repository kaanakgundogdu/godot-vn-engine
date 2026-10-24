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
## If false, the dialog box never shows side images, for any character.
@export var side_image_enabled: bool = true

@export_group("UI animations")
## If true, the dialog box and choice menu fade and slide in and out.
@export var ui_animations: bool = true
## Multiplier for UI animation times. 0.5 is twice as fast, 2.0 is twice as slow.
@export_range(0.25, 3.0, 0.05) var ui_animation_scale: float = 1.0

@export_group("Read text and choices")
## If true, lines the player has read before use seen_text_color. Players can turn it off in Settings.
@export var mark_seen_text: bool = true
## Text color for lines the player has read before.
@export var seen_text_color: Color = Color(0.72, 0.78, 0.88)
## If true, choices picked in any earlier playthrough are dimmed.
@export var mark_chosen_choices: bool = true

@export_group("Autosave")
## If true, the game saves to an auto slot right before each choice.
@export var autosave_before_choices: bool = true
## Number of rotating auto slots shown on the Auto page of the load panel.
@export_range(1, 12) var autosave_slots: int = 6
## If true, a small icon shows on autosave and a "Saved" note on manual and quick saves.
@export var save_notice: bool = true

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
