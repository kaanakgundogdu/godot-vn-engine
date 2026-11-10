class_name VNEngineGrowEffect
extends VNEngineRevealEffect

var bbcode: String = "grow"


func _process_custom_fx(fx: CharFXTransform) -> bool:
	var t: float = progress(fx, 0.25)
	if t >= 1.0:
		return true
	fade_in(fx, t)
	if not reduced():
		turn(fx, 0.0, maxf(VNEngineDropEffect.out_back(t), 0.01))
	return true
