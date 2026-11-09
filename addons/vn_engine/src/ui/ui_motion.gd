class_name VNEngineUiMotion
extends RefCounted

const ITEM_TIME: float = 0.18
const ITEM_STAGGER: float = 0.06


static func enabled() -> bool:
	return VNEngineMain.game().get_ui().ui_animations


static func reduced() -> bool:
	var settings: VNEngineSettings = VNEngineMain.settings()
	return settings != null and settings.reduce_motion


static func time(base: float) -> float:
	return base * VNEngineMain.game().get_ui().ui_animation_scale


static func stagger_in(items: Array[Control], offset: Vector2, first_delay: float = 0.0) -> Tween:
	var shown: Array[Control] = []
	for item: Control in items:
		if item.visible:
			shown.append(item)
	if shown.is_empty():
		return null
	if not enabled():
		for item: Control in shown:
			item.modulate.a = 1.0
		return null

	var tween: Tween = shown[0].create_tween().set_parallel(true)
	var is_reduced: bool = reduced()
	var item_time: float = time(ITEM_TIME)
	var rests: Dictionary = {}
	var index: int = 0
	for item: Control in shown:
		item.modulate.a = 0.0
		var delay: float = time(first_delay) if is_reduced else time(first_delay + index * ITEM_STAGGER)
		tween.tween_property(item, "modulate:a", 1.0, item_time).set_delay(delay)
		if not is_reduced and offset != Vector2.ZERO:
			tween.tween_method(_slide.bind(item, rests, offset), 0.0, 1.0, item_time).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		index += 1
	return tween


static func _slide(progress: float, item: Control, rests: Dictionary, offset: Vector2) -> void:
	if not rests.has(item):
		rests[item] = item.position
	item.position = rests[item] + offset * (1.0 - progress)
