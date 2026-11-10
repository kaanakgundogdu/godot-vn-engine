class_name VNEngineBounceEffect
extends VNEngineRevealEffect

var bbcode: String = "bounce"


func _process_custom_fx(fx: CharFXTransform) -> bool:
	if reduced():
		return true
	var duration: float = maxf(float(fx.env.get("time", 0.35)), 0.01)
	var t: float = age(fx) / duration
	if t >= 1.0:
		return true
	fx.offset.y -= float(fx.env.get("height", 8.0)) * sin(PI * t) * (1.0 - t * 0.5)
	return true
