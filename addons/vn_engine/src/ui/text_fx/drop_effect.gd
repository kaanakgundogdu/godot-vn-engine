class_name VNEngineDropEffect
extends VNEngineRevealEffect

var bbcode: String = "drop"


func _process_custom_fx(fx: CharFXTransform) -> bool:
	var t: float = progress(fx, 0.3)
	if t >= 1.0:
		return true
	fade_in(fx, t)
	if not reduced():
		fx.offset.y -= float(fx.env.get("height", 18.0)) * (1.0 - out_back(t))
	return true


static func out_back(t: float) -> float:
	var c: float = 1.70158
	return 1.0 + (c + 1.0) * pow(t - 1.0, 3.0) + c * pow(t - 1.0, 2.0)
