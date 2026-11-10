class_name VNEngineGhostEffect
extends VNEngineTextFxBase

var bbcode: String = "ghost"


func _process_custom_fx(fx: CharFXTransform) -> bool:
	var low: float = clampf(float(fx.env.get("min", 0.25)), 0.0, 1.0)
	var phase: float = now() * float(fx.env.get("freq", 1.5)) * TAU - fx.relative_index * 0.4
	fx.color.a *= lerpf(low, 1.0, (cos(phase) + 1.0) * 0.5)
	return true
