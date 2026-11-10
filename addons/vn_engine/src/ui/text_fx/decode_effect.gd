class_name VNEngineDecodeEffect
extends VNEngineRevealEffect

const CHARS: String = "ABCDEFGHJKLMNPQRSTUVWXYZ0123456789#$%&*+=?<>/"

var bbcode: String = "decode"


func _process_custom_fx(fx: CharFXTransform) -> bool:
	if reduced():
		return true
	var t: float = progress(fx, 0.6)
	if t >= 1.0:
		return true
	var step: int = int(now() * float(fx.env.get("rate", 25.0)))
	var pick: int = int(noise(fx.range.x, step) * CHARS.length()) % CHARS.length()
	swap_glyph(fx, CHARS.unicode_at(pick))
	fx.color = fx.color.lerp(Color(0.55, 1.0, 0.65, fx.color.a), 0.5)
	return true
