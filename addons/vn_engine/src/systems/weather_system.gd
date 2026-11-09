class_name VNEngineWeatherSystem
extends Node2D

const FOG_SHADER: Shader = preload("res://addons/vn_engine/src/shaders/fog.gdshader")
const RAIN_COUNT := 500
const SNOW_COUNT := 220

@export var runner: VNEngineStoryRunner

var current_type: String = ""
var current_strength: float = 0.0

var _current: CanvasItem
var _fade_in: Tween
var _rain_texture: ImageTexture
var _snow_texture: ImageTexture


func _ready() -> void:
	if runner:
		runner.state_restored.connect(_on_state_restored)
		runner.register_manager(self)


func set_weather(type: String, strength: float, fade: float) -> void:
	if type == current_type and is_equal_approx(strength, current_strength):
		return
	var same_fog: bool = type == "fog" and type == current_type
	current_strength = strength
	if same_fog:
		_tween_fog(strength, fade)
		return
	_drop_current(fade)
	current_type = type
	_current = _build(type, strength)
	add_child(_current)
	if fade <= 0.0:
		return
	_current.modulate.a = 0.0
	_fade_in = _current.create_tween()
	_fade_in.tween_property(_current, "modulate:a", 1.0, fade)


func stop(fade: float) -> void:
	_drop_current(fade)
	current_type = ""
	current_strength = 0.0


func _drop_current(fade: float) -> void:
	var old: CanvasItem = _current
	_current = null
	if old == null:
		return
	if fade <= 0.0:
		old.queue_free()
		return
	var tween: Tween = old.create_tween()
	tween.tween_property(old, "modulate:a", 0.0, fade)
	tween.tween_callback(old.queue_free)


func _tween_fog(strength: float, fade: float) -> void:
	var rect: ColorRect = _current as ColorRect
	var material: ShaderMaterial = rect.material as ShaderMaterial
	if fade <= 0.0:
		material.set_shader_parameter("strength", strength)
		return
	var from: float = material.get_shader_parameter("strength")
	rect.create_tween().tween_method(func(value: float) -> void: material.set_shader_parameter("strength", value), from, strength, fade)


func _on_state_restored(state: VNEngineStoryState) -> void:
	var data: Dictionary = state.weather
	var type: String = data.get("type", "")
	var strength: float = data.get("strength", 0.6)
	if type == "":
		for child: Node in get_children():
			child.queue_free()
		_current = null
		current_type = ""
		current_strength = 0.0
		return
	if _current != null and type == current_type and is_equal_approx(strength, current_strength):
		if _fade_in and _fade_in.is_valid():
			_fade_in.kill()
		_current.modulate.a = 1.0
		return
	for child: Node in get_children():
		child.queue_free()
	_current = null
	current_type = ""
	set_weather(type, strength, 0.0)


func _build(type: String, strength: float) -> CanvasItem:
	match type:
		"rain":
			return _build_rain(strength)
		"snow":
			return _build_snow(strength)
	return _build_fog(strength)


func _screen() -> Vector2:
	return get_viewport_rect().size


func _build_rain(strength: float) -> CPUParticles2D:
	var screen: Vector2 = _screen()
	var rain := CPUParticles2D.new()
	rain.texture = _rain_tex()
	rain.amount = maxi(int(RAIN_COUNT * strength), 1)
	rain.lifetime = 0.8
	rain.preprocess = 0.8
	rain.position = Vector2(screen.x * 0.5, -60.0)
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(screen.x * 0.5 + 300.0, 1.0)
	rain.direction = Vector2(0.2, 1.0)
	rain.spread = 1.5
	rain.gravity = Vector2.ZERO
	rain.initial_velocity_min = 1500.0
	rain.initial_velocity_max = 1900.0
	rain.scale_amount_min = 0.8
	rain.scale_amount_max = 1.4
	rain.color = Color(0.82, 0.9, 1.0, 0.85)
	rain.particle_flag_align_y = true
	return rain


func _build_snow(strength: float) -> CPUParticles2D:
	var screen: Vector2 = _screen()
	var snow := CPUParticles2D.new()
	snow.texture = _snow_tex()
	snow.amount = maxi(int(SNOW_COUNT * strength), 1)
	snow.lifetime = 14.0
	snow.preprocess = 14.0
	snow.position = Vector2(screen.x * 0.5, -30.0)
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(screen.x * 0.5 + 150.0, 1.0)
	snow.direction = Vector2(0.15, 1.0)
	snow.spread = 25.0
	snow.gravity = Vector2(0.0, 6.0)
	snow.initial_velocity_min = 55.0
	snow.initial_velocity_max = 110.0
	snow.tangential_accel_min = -12.0
	snow.tangential_accel_max = 12.0
	snow.scale_amount_min = 0.5
	snow.scale_amount_max = 1.5
	snow.color = Color(1.0, 1.0, 1.0, 0.9)
	return snow


func _build_fog(strength: float) -> ColorRect:
	var screen: Vector2 = _screen()
	var fog := ColorRect.new()
	fog.size = screen
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = FOG_SHADER
	material.set_shader_parameter("strength", strength)
	material.set_shader_parameter("aspect", screen.x / screen.y)
	fog.material = material
	return fog


func _rain_tex() -> ImageTexture:
	if _rain_texture == null:
		var image := Image.create(4, 72, false, Image.FORMAT_RGBA8)
		for y: int in 72:
			var alpha: float = pow(float(y) / 71.0, 1.3)
			image.set_pixel(0, y, Color(1, 1, 1, alpha * 0.3))
			image.set_pixel(1, y, Color(1, 1, 1, alpha))
			image.set_pixel(2, y, Color(1, 1, 1, alpha))
			image.set_pixel(3, y, Color(1, 1, 1, alpha * 0.3))
		_rain_texture = ImageTexture.create_from_image(image)
	return _rain_texture


func _snow_tex() -> ImageTexture:
	if _snow_texture == null:
		var size: int = 24
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var center: float = (size - 1) * 0.5
		for y: int in size:
			for x: int in size:
				var dist: float = Vector2(x - center, y - center).length() / center
				var alpha: float = clampf(1.0 - dist, 0.0, 1.0)
				image.set_pixel(x, y, Color(1, 1, 1, alpha * alpha * (3.0 - 2.0 * alpha)))
		_snow_texture = ImageTexture.create_from_image(image)
	return _snow_texture
