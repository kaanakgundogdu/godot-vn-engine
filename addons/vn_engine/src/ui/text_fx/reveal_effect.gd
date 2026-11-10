class_name VNEngineRevealEffect
extends VNEngineTextFxBase

var reveal: bool = true
var _seen: Dictionary = {}
var _frame: int = -1
var _text: String = ""
var _shown: int = 0


func reset() -> void:
	_seen.clear()


func age(fx: CharFXTransform) -> float:
	if not reveal:
		return INF
	_watch_label()
	var time: float = now()
	return time - float(_seen.get_or_add(fx.range.x, time))


func progress(fx: CharFXTransform, default_time: float) -> float:
	var duration: float = maxf(float(fx.env.get("time", default_time)), 0.01)
	return clampf(age(fx) / duration, 0.0, 1.0)


func fade_in(fx: CharFXTransform, t: float) -> void:
	fx.color.a *= clampf(t * 2.5, 0.0, 1.0)


func _watch_label() -> void:
	var frame: int = Engine.get_process_frames()
	if frame == _frame:
		return
	_frame = frame
	var label: RichTextLabel = _label.get_ref() as RichTextLabel if _label != null else null
	if label == null:
		return
	var shown: int = label.visible_characters if label.visible_characters >= 0 else 1 << 30
	if label.text != _text or shown < _shown:
		_text = label.text
		reset()
	_shown = shown
