class_name VNEngineBackgroundSystem
extends Control

@export var runner: VNEngineStoryRunner
@export var fade_duration: float = 0.5

@onready var current_layer: TextureRect = $LayerA
@onready var incoming_layer: TextureRect = $LayerB

var current_bg_name: String = ""

var _active_layer: TextureRect
var _inactive_layer: TextureRect
var _bg_tween: Tween


func _ready() -> void:
	if runner:
		runner.state_restored.connect(_on_state_restored)
		runner.register_manager(self)

	_active_layer = current_layer
	_inactive_layer = incoming_layer
	_inactive_layer.modulate.a = 0.0


func change_to(bg_name: String, transition: String = "fade", duration: float = -1.0, kind: String = "background") -> void:
	if bg_name == current_bg_name:
		return

	var file_path: String = runner.ctx.assets.resolve(kind, bg_name)
	if file_path == "":
		return

	var new_texture: Texture2D = load(file_path) as Texture2D
	var actual_duration: float = duration if duration >= 0.0 else fade_duration

	current_bg_name = bg_name

	if _bg_tween and _bg_tween.is_valid():
		_bg_tween.kill()

	if transition == "instant":
		_active_layer.texture = new_texture
		_active_layer.modulate.a = 1.0
		_inactive_layer.modulate.a = 0.0
		return

	_inactive_layer.texture = new_texture
	_inactive_layer.modulate.a = 0.0
	move_child(_inactive_layer, get_child_count() - 1)

	var trans_type: Tween.TransitionType = Tween.TRANS_SINE if transition == "dissolve" else Tween.TRANS_LINEAR

	_bg_tween = create_tween()
	_bg_tween.set_trans(trans_type)
	_bg_tween.tween_property(_inactive_layer, "modulate:a", 1.0, actual_duration)
	_bg_tween.tween_callback(_on_crossfade_finished)


func _on_state_restored(state: VNEngineStoryState) -> void:
	var kind: String = "background"
	var id: String = state.bg

	if state.cg != "":
		kind = "cg"
		id = state.cg

	if id == "":
		return

	var file_path: String = runner.ctx.assets.resolve(kind, id)
	if file_path == "":
		return

	if _bg_tween and _bg_tween.is_valid():
		_bg_tween.kill()

	_active_layer.texture = load(file_path) as Texture2D
	_active_layer.modulate.a = 1.0
	_inactive_layer.modulate.a = 0.0
	current_bg_name = id


func _on_crossfade_finished() -> void:
	var previous_active_layer: TextureRect = _active_layer
	_active_layer = _inactive_layer
	_inactive_layer = previous_active_layer
	_inactive_layer.modulate.a = 0.0
