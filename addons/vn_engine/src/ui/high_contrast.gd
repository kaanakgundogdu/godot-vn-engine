class_name VNEngineHighContrast
extends RefCounted

const TEXT := Color(1.0, 1.0, 1.0, 1.0)
const BACK := Color(0.0, 0.0, 0.0, 1.0)
const BORDER := Color(1.0, 1.0, 1.0, 0.9)
const BORDER_WIDTH := 3


static func on() -> bool:
	var settings: VNEngineSettings = VNEngineMain.settings()
	return settings != null and settings.high_contrast


static func box(base: StyleBox) -> StyleBoxFlat:
	var style: StyleBoxFlat
	if base is StyleBoxFlat:
		style = base.duplicate()
	else:
		style = StyleBoxFlat.new()
		if base != null:
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				style.set_content_margin(side, base.get_content_margin(side))
	style.bg_color = BACK
	style.border_color = BORDER
	style.set_border_width_all(BORDER_WIDTH)
	return style
