class_name VNEngineSpinEffect
extends VNEngineRevealEffect

var bbcode: String = "spin"


func _process_custom_fx(fx: CharFXTransform) -> bool:
	var t: float = progress(fx, 0.35)
	if t >= 1.0:
		return true
	fade_in(fx, t)
	if not reduced():
		var left: float = pow(1.0 - t, 3.0)
		turn(fx, deg_to_rad(float(fx.env.get("angle", 90.0))) * left, 1.0 - 0.5 * left)
	return true
