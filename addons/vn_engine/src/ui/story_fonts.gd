class_name VNEngineStoryFonts
extends RefCounted

const DEFAULT := "default"
const ATKINSON := "atkinson"
const OPENDYSLEXIC := "opendyslexic"
const IDS: Array[String] = [DEFAULT, ATKINSON, OPENDYSLEXIC]
const NAMES: Dictionary = {DEFAULT: "Default", ATKINSON: "Atkinson Hyperlegible", OPENDYSLEXIC: "OpenDyslexic"}

const _FILES: Dictionary = {
	ATKINSON: ["res://addons/vn_engine/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.ttf", "res://addons/vn_engine/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Bold.ttf"],
	OPENDYSLEXIC: ["res://addons/vn_engine/fonts/opendyslexic/OpenDyslexic-Regular.woff2", "res://addons/vn_engine/fonts/opendyslexic/OpenDyslexic-Bold.woff2"],
}
const ITALIC_SLANT := 0.2

static var _cache: Dictionary = {}


static func font_for(id: String, bold: bool, italic: bool) -> Font:
	if not _FILES.has(id):
		return null
	var key: String = "%s/%s/%s" % [id, bold, italic]
	if not _cache.has(key):
		var font: Font = load(_FILES[id][1 if bold else 0])
		if italic:
			var slanted := FontVariation.new()
			slanted.base_font = font
			slanted.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(ITALIC_SLANT, 1.0), Vector2.ZERO)
			font = slanted
		_cache[key] = font
	return _cache[key]
