class_name VNEngineScreenFader
extends ColorRect

const TRANSITION_SHADER: Shader = preload("res://addons/vn_engine/src/shaders/transition.gdshader")

const KINDS: PackedStringArray = [
	"fade", "wipe_left", "wipe_right", "wipe_up", "wipe_down", "shutter", "flash",
	"slide_left", "slide_right", "slide_up", "slide_down", "instant",
]

const REVERSED: Dictionary = {
	"wipe_left": "wipe_right",
	"wipe_right": "wipe_left",
	"wipe_up": "wipe_down",
	"wipe_down": "wipe_up",
	"slide_left": "slide_right",
	"slide_right": "slide_left",
	"slide_up": "slide_down",
	"slide_down": "slide_up",
}

var _material: ShaderMaterial
var _tween: Tween
var _progress: float = 0.0


func _init() -> void:
	name = "ScreenFader"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(0, 0, 0, 0)
	_material = ShaderMaterial.new()
	_material.shader = TRANSITION_SHADER
	_material.set_shader_parameter("progress", 0.0)
	material = _material


static func is_slide(kind: String) -> bool:
	return kind.begins_with("slide_")


static func reversed(kind: String) -> String:
	return REVERSED.get(kind, kind)


func is_covered() -> bool:
	return _progress >= 1.0


func cover(kind: String, time: float) -> void:
	_set_kind(kind)
	mouse_filter = Control.MOUSE_FILTER_STOP
	await _run(1.0, time)


func reveal(kind: String, time: float) -> void:
	_set_kind(kind)
	await _run(0.0, time)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func clear() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_set_progress(0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_kind(kind: String) -> void:
	var kind_int: int = VNEngineTransitionPlayer.KIND_MAP.get(StringName(kind), VNEngineTransitionPlayer.Kind.FADE)
	if kind_int == VNEngineTransitionPlayer.Kind.INSTANT:
		kind_int = VNEngineTransitionPlayer.Kind.FADE
	_material.set_shader_parameter("kind", kind_int)
	_material.set_shader_parameter("color", Color.WHITE if kind == "flash" else Color.BLACK)


func _run(target: float, time: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var duration: float = time * absf(target - _progress)
	if duration <= 0.0:
		_set_progress(target)
		return
	_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_tween.tween_method(_set_progress, _progress, target, duration)
	await _tween.finished


func _set_progress(value: float) -> void:
	_progress = value
	_material.set_shader_parameter("progress", value)
