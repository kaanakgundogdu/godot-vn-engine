class_name VNEnginePopEffect
extends VNEngineRevealEffect

var bbcode: String = "pop"


func _process_custom_fx(fx: CharFXTransform) -> bool:
	var duration: float = maxf(float(fx.env.get("time", 0.2)), 0.01)
	var t: float = clampf(age(fx) / duration, 0.0, 1.0)
	if t >= 1.0:
		return true
	var eased: float = ease(t, 0.4)
	fx.color.a *= eased
	if not reduced():
		fx.offset.y += float(fx.env.get("rise", 6.0)) * (1.0 - eased)
	return true
