class_name VNEngineTransitionPlayer
extends ColorRect

signal transition_started
signal transition_finished

enum Kind { FADE, WIPE_LEFT, WIPE_RIGHT, WIPE_UP, WIPE_DOWN, SHUTTER, FLASH, INSTANT }

const KIND_MAP: Dictionary = {
	&"fade": Kind.FADE,
	&"wipe_left": Kind.WIPE_LEFT,
	&"wipe_right": Kind.WIPE_RIGHT,
	&"wipe_up": Kind.WIPE_UP,
	&"wipe_down": Kind.WIPE_DOWN,
	&"shutter": Kind.SHUTTER,
	&"flash": Kind.FLASH,
	&"instant": Kind.INSTANT,
}

const DEFAULT_COLOR_BY_KIND: Dictionary = {
	Kind.FLASH: Color.WHITE,
}

var _tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(0.0, 0.0, 0.0, 0.0)


func play(kind: StringName, params: Dictionary = {}) -> void:
	var duration: float = params.get("duration", 0.5)
	var params_color: Variant = params.get("color")
	await _run(kind, duration, 0.0, 1.0, params_color)
	await _run(kind, duration, 1.0, 0.0, params_color)


func _run(kind: StringName, duration: float, from_progress: float, to_progress: float, override_color: Variant) -> void:
	var mat: ShaderMaterial = material as ShaderMaterial
	var kind_int: int = KIND_MAP.get(kind, Kind.FADE)
	var effective_duration: float = 0.0 if kind_int == Kind.INSTANT else duration

	var col: Color = override_color if (override_color is Color) else DEFAULT_COLOR_BY_KIND.get(kind_int, Color.BLACK)
	mat.set_shader_parameter("kind", kind_int)
	mat.set_shader_parameter("color", col)

	if _tween and _tween.is_valid():
		_tween.kill()

	transition_started.emit()
	mouse_filter = Control.MOUSE_FILTER_STOP

	if effective_duration <= 0.0:
		mat.set_shader_parameter("progress", to_progress)
	else:
		mat.set_shader_parameter("progress", from_progress)
		_tween = create_tween()
		_tween.tween_method(
			func(p: float) -> void: mat.set_shader_parameter("progress", p),
			from_progress, to_progress, effective_duration
		)
		await _tween.finished

	if to_progress <= 0.0:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_finished.emit()
