class_name VNEngineCharacterSprite
extends Control

@onready var sprite: TextureRect = $Sprite

var _fade_tween: Tween
var _move_tween: Tween
var _tint_tween: Tween


func _ready() -> void:
	modulate.a = 0.0


func set_expression(image_path: String) -> void:
	if image_path == "":
		return
	if ResourceLoader.exists(image_path):
		sprite.texture = load(image_path) as Texture2D
	else:
		VNEngineLog.warn("CharacterSprite", "Image not found: %s" % image_path)


func move_to(x_ratio: float, duration: float) -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

	_move_tween = create_tween()
	_move_tween.set_parallel(true)
	_move_tween.tween_property(self, "anchor_left", x_ratio, duration)
	_move_tween.tween_property(self, "anchor_right", x_ratio, duration)


func enter(transition: String) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	if transition == "instant":
		modulate.a = 1.0
	else:
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "modulate:a", 1.0, 0.6)


func exit(transition: String) -> void:
	if transition == "instant":
		queue_free()
		return

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	_fade_tween.tween_callback(queue_free)


func focus() -> void:
	_tint_to(Color.WHITE)
	z_index = 1


func unfocus() -> void:
	_tint_to(Color(0.5, 0.5, 0.5, 1.0))
	z_index = 0


func _tint_to(color: Color) -> void:
	if _tint_tween and _tint_tween.is_valid():
		_tint_tween.kill()
	_tint_tween = create_tween()
	_tint_tween.tween_property(sprite, "modulate", color, 0.2)
