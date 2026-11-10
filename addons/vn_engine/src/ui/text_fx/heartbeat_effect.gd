class_name VNEngineHeartbeatEffect
extends VNEngineTextFxBase

var bbcode: String = "heartbeat"


func _process_custom_fx(fx: CharFXTransform) -> bool:
	if reduced():
		return true
	var p: float = fmod(now() * float(fx.env.get("rate", 1.2)), 1.0)
	var beat: float = maxf(0.0, 1.0 - absf(p - 0.06) / 0.08) + 0.7 * maxf(0.0, 1.0 - absf(p - 0.3) / 0.08)
	turn(fx, 0.0, 1.0 + float(fx.env.get("scale", 0.18)) * beat)
	return true
