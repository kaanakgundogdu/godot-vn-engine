class_name VNEngineSwayEffect
extends VNEngineTextFxBase

var bbcode: String = "sway"


func _process_custom_fx(fx: CharFXTransform) -> bool:
	if reduced():
		return true
	var phase: float = now() * float(fx.env.get("freq", 1.2)) * TAU + fx.relative_index * 0.35
	turn(fx, deg_to_rad(float(fx.env.get("angle", 12.0))) * sin(phase), 1.0)
	return true
