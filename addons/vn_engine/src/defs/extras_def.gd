@tool
class_name VNEngineExtrasDef
extends Resource

@export_group("Rooms")
## Shows the CG gallery room in extras.
@export var show_gallery: bool = true
## Shows the music room in extras.
@export var show_music: bool = true
## Shows the endings room in extras.
@export var show_endings: bool = true
## Shows the movies room in extras.
@export var show_movies: bool = true

@export_group("Locked entries")
## "placeholder" = flat card + locked_text, "blur" = blurred real image,
## "image" = locked_image on every locked card.
@export_enum("placeholder", "blur", "image") var locked_style: String = "placeholder"
## Text on a locked gallery card.
@export var locked_text: String = "?"
## Name shown for a locked music/movie/ending entry.
@export var locked_name_text: String = "???"
## Whole row text for an unseen ending whose is_secret is true.
@export var secret_ending_text: String = "???"
## Image used on every locked card when locked_style is "image".
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp", "*.svg") var locked_image: String = ""
## Blur amount used when locked_style is "blur".
@export_range(0.0, 8.0, 0.1) var blur_strength: float = 4.0

@export_group("Entries")
## CG gallery entries. Empty shows every "cg" id from the asset map.
@export var gallery_items: Array[VNEngineExtrasItem] = []
## Music room entries. Empty shows every "music" id from the asset map.
@export var music_items: Array[VNEngineExtrasItem] = []
## Movie room entries. Empty shows every "movie" id from the asset map.
@export var movie_items: Array[VNEngineExtrasItem] = []
