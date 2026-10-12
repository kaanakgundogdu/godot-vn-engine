class_name VNEngineChoiceTimerDial
extends Control

## Color of the slice that shows the time left. It shrinks as time runs out.
@export var fill_color: Color = Color(0.06, 0.06, 0.08, 0.9)
## Color of the full circle behind the slice.
@export var track_color: Color = Color(1.0, 1.0, 1.0, 0.25)
## Color of the outer ring.
@export var ring_color: Color = Color(1.0, 1.0, 1.0, 0.9)
## Color of the seconds number in the middle.
@export var text_color: Color = Color.WHITE

var _total: float = 1.0
var _remaining: float = 1.0


func _init() -> void:
	custom_minimum_size = Vector2(88, 88)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_time(remaining: float, total: float) -> void:
	_remaining = maxf(remaining, 0.0)
	_total = maxf(total, 0.001)
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0 - 3.0
	var ratio: float = clampf(_remaining / _total, 0.0, 1.0)

	draw_circle(center, radius, track_color)

	if ratio >= 0.999:
		draw_circle(center, radius, fill_color)
	elif ratio > 0.0:
		var start: float = -PI / 2.0
		var end: float = start + TAU * ratio
		var steps: int = maxi(int(64.0 * ratio), 2)
		var points := PackedVector2Array([center])
		for i in steps + 1:
			var angle: float = lerpf(start, end, float(i) / float(steps))
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, fill_color)

	draw_arc(center, radius, 0.0, TAU, 64, ring_color, 3.0, true)

	var font: Font = get_theme_default_font()
	var font_size: int = int(radius * 0.8)
	var text: String = str(ceili(_remaining))
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline: Vector2 = center + Vector2(-text_size.x / 2.0, (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0, 0, 0, 0.8))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
