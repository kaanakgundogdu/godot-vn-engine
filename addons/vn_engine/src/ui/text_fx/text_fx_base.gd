class_name VNEngineTextFxBase
extends RichTextEffect

const DEFAULT_SIZE: int = 32

var _label: WeakRef = null


func bind(label: RichTextLabel) -> void:
	_label = weakref(label)


func font_size() -> int:
	var label: RichTextLabel = _label.get_ref() as RichTextLabel if _label != null else null
	if label == null:
		return DEFAULT_SIZE
	return label.get_theme_font_size(&"normal_font_size")


func pivot(fx: CharFXTransform) -> Vector2:
	var size: int = font_size()
	var width: float = float(size) * 0.5
	if fx.font.is_valid():
		width = TextServerManager.get_primary_interface().font_get_glyph_advance(fx.font, size, fx.glyph_index).x
	return Vector2(width * 0.5, -float(size) * 0.35)


func turn(fx: CharFXTransform, angle: float, scale: float) -> void:
	var center: Vector2 = pivot(fx)
	fx.transform = fx.transform.translated_local(center).rotated_local(angle).scaled_local(Vector2(scale, scale)).translated_local(-center)


func swap_glyph(fx: CharFXTransform, code: int) -> void:
	if not fx.font.is_valid():
		return
	var glyph: int = TextServerManager.get_primary_interface().font_get_glyph_index(fx.font, font_size(), code, 0)
	if glyph != 0:
		fx.glyph_index = glyph


static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


static func reduced() -> bool:
	return VNEngineUiMotion.reduced()


static func noise(a: int, b: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(a, b))
	return rng.randf()
