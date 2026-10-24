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
var _view_tween: Tween
var _view_scale: float = 1.0
var _view_focus: Vector2 = Vector2(0.5, 0.5)


func _ready() -> void:
	if runner:
		runner.state_restored.connect(_on_state_restored)
		runner.register_manager(self)

	_active_layer = current_layer
	_inactive_layer = incoming_layer
	_inactive_layer.modulate.a = 0.0
	pivot_offset = Vector2.ZERO
	resized.connect(_apply_view)


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
	_restore_view(state.bg_view)
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

func set_view(view_scale: float, focus: Vector2, time: float) -> void:
	var target_scale: float = maxf(view_scale, 1.0)
	var target_focus: Vector2 = Vector2(clampf(focus.x, 0.0, 1.0), clampf(focus.y, 0.0, 1.0))
	if _view_tween and _view_tween.is_valid():
		_view_tween.kill()
	if time <= 0.0:
		_view_scale = target_scale
		_view_focus = target_focus
		_apply_view()
		return
	var from_scale: float = _view_scale
	var from_focus: Vector2 = _view_focus
	_view_tween = create_tween()
	_view_tween.set_trans(Tween.TRANS_SINE)
	_view_tween.set_ease(Tween.EASE_IN_OUT)
	_view_tween.tween_method(func(t: float) -> void:
		_view_scale = lerpf(from_scale, target_scale, t)
		_view_focus = from_focus.lerp(target_focus, t)
		_apply_view(), 0.0, 1.0, time)


func get_view() -> Dictionary:
	return {"scale": _view_scale, "x": _view_focus.x, "y": _view_focus.y}


func _restore_view(view: Dictionary) -> void:
	if view.is_empty():
		set_view(1.0, Vector2(0.5, 0.5), 0.0)
	else:
		set_view(float(view.get("scale", 1.0)), Vector2(float(view.get("x", 0.5)), float(view.get("y", 0.5))), 0.0)


func _apply_view() -> void:
	scale = Vector2(_view_scale, _view_scale)
	var area: Vector2 = size
	var wanted: Vector2 = area * 0.5 - _view_focus * area * _view_scale
	position = Vector2(clampf(wanted.x, area.x * (1.0 - _view_scale), 0.0), clampf(wanted.y, area.y * (1.0 - _view_scale), 0.0))
