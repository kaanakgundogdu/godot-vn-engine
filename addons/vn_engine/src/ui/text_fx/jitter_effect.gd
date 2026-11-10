class_name VNEngineJitterEffect
extends VNEngineTextFxBase

var bbcode: String = "jitter"


func _process_custom_fx(fx: CharFXTransform) -> bool:
	if reduced():
		return true
	var amp: float = float(fx.env.get("amp", 1.5))
	var rate: float = maxf(float(fx.env.get("rate", 20.0)), 0.1)
	var step: int = int(now() * rate)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(fx.range.x, step))
	fx.offset += Vector2(rng.randf_range(-amp, amp), rng.randf_range(-amp, amp))
	return true
