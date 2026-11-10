class_name VNEngineTextEffects
extends RefCounted

const MOTION_TAGS: Array[String] = ["wave", "shake", "tornado"]

static var _motion_tag: RegEx = null


static func install(label: RichTextLabel, reveal: bool = true) -> void:
	var effects: Array = [
		VNEnginePopEffect.new(), VNEngineBounceEffect.new(), VNEngineDropEffect.new(), VNEngineGrowEffect.new(),
		VNEngineSpinEffect.new(), VNEngineDecodeEffect.new(), VNEngineJitterEffect.new(), VNEngineGlitchEffect.new(),
		VNEngineGhostEffect.new(), VNEngineHeartbeatEffect.new(), VNEngineSwayEffect.new(),
	]
	for effect: VNEngineTextFxBase in effects:
		if effect is VNEngineRevealEffect:
			(effect as VNEngineRevealEffect).reveal = reveal
		effect.bind(label)
	label.custom_effects = effects


static func prepare(text: String, pop: bool = false) -> String:
	if VNEngineUiMotion.reduced() and text.contains("["):
		if _motion_tag == null:
			_motion_tag = RegEx.create_from_string(r"\[/?(%s)([= ][^\[\]]*)?\]" % "|".join(MOTION_TAGS))
		text = _motion_tag.sub(text, "", true)
	if pop and text != "":
		text = "[pop]%s[/pop]" % text
	return text
