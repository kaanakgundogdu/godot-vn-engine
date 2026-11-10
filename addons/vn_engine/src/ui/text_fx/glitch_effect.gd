class_name VNEngineGlitchEffect
extends VNEngineTextFxBase

const CHARS: String = "#%&@$/|<>?!01"
const RED: Color = Color(1.0, 0.25, 0.35)
const CYAN: Color = Color(0.3, 0.95, 1.0)

var bbcode: String = "glitch"


func _process_custom_fx(fx: CharFXTransform) -> bool:
	if reduced():
		return true
	var slot: int = int(now() * 10.0)
	var span: int = fx.range.x - fx.relative_index
	if noise(span, slot) >= float(fx.env.get("rate", 0.2)):
		return true
	var n: float = noise(fx.range.x, slot * 7 + 1)
	fx.offset.x += (n - 0.5) * 2.0 * float(fx.env.get("amp", 4.0))
	if noise(fx.range.x, slot * 13 + 2) < 0.3:
		swap_glyph(fx, CHARS.unicode_at(int(n * CHARS.length()) % CHARS.length()))
	fx.color = fx.color.lerp(Color(RED if n > 0.5 else CYAN, fx.color.a), 0.7)
	return true
