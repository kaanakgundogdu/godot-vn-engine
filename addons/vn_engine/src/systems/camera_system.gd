class_name VNEngineCameraSystem
extends Camera2D

@export var runner: VNEngineStoryRunner

var shake_intensity: float = 0.0
var shake_duration: float = 0.0

var _original_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_original_offset = offset
	if runner:
		runner.register_manager(self)


func _process(delta: float) -> void:
	if shake_duration > 0:
		shake_duration -= delta
		var random_x: float = randf_range(-shake_intensity, shake_intensity)
		var random_y: float = randf_range(-shake_intensity, shake_intensity)
		offset = _original_offset + Vector2(random_x, random_y)
	else:
		offset = _original_offset


func shake(param: String) -> void:
	shake_intensity = param.to_float() if param.is_valid_float() else 10.0
	shake_duration = 0.4
