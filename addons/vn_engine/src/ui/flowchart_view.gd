class_name VNEngineFlowchartView
extends Control

signal box_activated(box_id: String)

const BOX_SIZE: Vector2 = Vector2(228, 76)
const LAYER_GAP: float = 96.0
const ROW_GAP: float = 40.0
const MARGIN: float = 64.0
const STRIP_WIDTH: float = 8.0
const CORNER_RADIUS: float = 10.0
const ARROW_SIZE: float = 9.0
const TITLE_FONT_SIZE: int = 22
const KIND_FONT_SIZE: int = 14
const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 2.0
const ZOOM_STEP: float = 1.15
const DRAG_THRESHOLD: float = 6.0
const FIT_ALL: String = "*"

const CHAPTER_COLORS: Array[Color] = [
	Color(0.36, 0.62, 0.95),
	Color(0.95, 0.56, 0.36),
	Color(0.48, 0.84, 0.56),
	Color(0.86, 0.46, 0.80),
	Color(0.96, 0.84, 0.38),
	Color(0.42, 0.84, 0.88),
]
const ENDING_STRIP: Color = Color(0.85, 0.85, 0.9)
const BACKGROUND: Color = Color(0.0, 0.0, 0.0, 0.25)
const BOX_BG: Color = Color(0.10, 0.10, 0.15, 0.95)
const BOX_BG_LOCKED: Color = Color(0.06, 0.06, 0.09, 0.8)
const BOX_BORDER: Color = Color(1.0, 1.0, 1.0, 0.16)
const BOX_BORDER_LOCKED: Color = Color(1.0, 1.0, 1.0, 0.06)
const BOX_BORDER_HOVER: Color = Color(0.45, 0.8, 1.0, 0.7)
const BOX_BORDER_CURRENT: Color = Color(1.0, 0.85, 0.4, 1.0)
const BOX_GLOW_CURRENT: Color = Color(1.0, 0.85, 0.4, 0.22)
const EDGE_BRIGHT: Color = Color(1.0, 1.0, 1.0, 0.55)
const EDGE_DIM: Color = Color(1.0, 1.0, 1.0, 0.14)
const EDGE_PATH: Color = Color(1.0, 0.85, 0.4, 0.95)
const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.95)
const TEXT_LOCKED: Color = Color(1.0, 1.0, 1.0, 0.35)
const TEXT_KIND: Color = Color(1.0, 1.0, 1.0, 0.5)
const LOCKED_ALPHA: float = 0.45

var _graph: VNEngineFlowGraph = null
var _current_box: String = ""
var _path: Array[String] = []
var _locked_text: String = "???"

var _rects: Dictionary = {}
var _reached: Dictionary = {}
var _clickable: Dictionary = {}
var _edge_lines: Array[Dictionary] = []

var _offset: Vector2 = Vector2.ZERO
var _zoom: float = 1.0
var _dragging: bool = false
var _drag_moved: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _hover_id: String = ""
var _pending_center: String = ""

var _box_style: StyleBoxFlat = StyleBoxFlat.new()
var _strip_style: StyleBoxFlat = StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_strip_style.corner_radius_top_right = 0
	_strip_style.corner_radius_bottom_right = 0


func set_locked_text(text: String) -> void:
	_locked_text = text


func set_graph(graph: VNEngineFlowGraph, current_box: String, path: Array[String]) -> void:
	_graph = graph
	_current_box = current_box
	_path = path.duplicate()
	_hover_id = ""
	_rects.clear()
	_reached.clear()
	_clickable.clear()
	_edge_lines.clear()

	if _graph == null:
		queue_redraw()
		return

	var save_data: VNEngineSaveData = VNEngineMain.save_data()
	for id: String in _graph.box_ids:
		var box: VNEngineFlowGraph.Box = _graph.boxes[id]
		_rects[id] = _slot_rect(box.layer, box.row)

		var reached: bool = id == _current_box or (save_data != null and save_data.is_flow_reached(id))
		_reached[id] = reached
		_clickable[id] = reached and box.kind != "ending" and save_data != null and save_data.has_flow_snapshot(id)

	_build_edge_lines()
	if _pending_center != "":
		var target: String = _pending_center
		_pending_center = ""
		center_on(target)
	queue_redraw()


func center_on(box_id: String) -> void:
	if not _rects.has(box_id) and box_id != FIT_ALL:
		_pending_center = box_id
		return
	if size.x <= 0.0 or size.y <= 0.0:
		_pending_center = box_id
		return
	if box_id == FIT_ALL:
		_fit_all()
		return
	var rect: Rect2 = _rects[box_id]
	_offset = size * 0.5 - rect.get_center() * _zoom
	queue_redraw()


func fit_all() -> void:
	center_on(FIT_ALL)


func _fit_all() -> void:
	if _rects.is_empty():
		return
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for id: String in _rects:
		var rect: Rect2 = _rects[id]
		bounds = rect if first else bounds.merge(rect)
		first = false
	bounds = bounds.grow(MARGIN * 0.5)
	_zoom = clampf(minf(size.x / bounds.size.x, size.y / bounds.size.y), MIN_ZOOM, 1.0)
	_offset = size * 0.5 - bounds.get_center() * _zoom
	queue_redraw()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			if _pending_center != "":
				var target: String = _pending_center
				_pending_center = ""
				center_on(target)
		NOTIFICATION_MOUSE_EXIT:
			if _hover_id != "":
				_hover_id = ""
				queue_redraw()


func _build_edge_lines() -> void:
	var path_keys: Dictionary = {}
	for i in range(_path.size() - 1):
		path_keys["%s>%s" % [_path[i], _path[i + 1]]] = true

	var dim: Array[Dictionary] = []
	var bright: Array[Dictionary] = []
	var on_path: Array[Dictionary] = []
	for edge: VNEngineFlowGraph.Edge in _graph.edges:
		if not _rects.has(edge.from_id) or not _rects.has(edge.to_id):
			continue
		var from_rect: Rect2 = _rects[edge.from_id]
		var to_rect: Rect2 = _rects[edge.to_id]
		var from_box: VNEngineFlowGraph.Box = _graph.boxes[edge.from_id]
		var to_box: VNEngineFlowGraph.Box = _graph.boxes[edge.to_id]
		var points: PackedVector2Array
		if edge.from_id == edge.to_id:
			points = _route_self_loop(from_rect)
		else:
			points = _route_edge(from_rect, to_rect, edge.is_back or to_box.layer <= from_box.layer, edge.waypoints)
		var line: Dictionary = {"points": points}
		if path_keys.has("%s>%s" % [edge.from_id, edge.to_id]):
			line["color"] = EDGE_PATH
			line["width"] = 3.0
			on_path.append(line)
		elif _reached.get(edge.from_id, false) and _reached.get(edge.to_id, false):
			line["color"] = EDGE_BRIGHT
			line["width"] = 2.0
			bright.append(line)
		else:
			line["color"] = EDGE_DIM
			line["width"] = 1.5
			dim.append(line)
	_edge_lines.append_array(dim)
	_edge_lines.append_array(bright)
	_edge_lines.append_array(on_path)


func _slot_rect(layer: int, row: int) -> Rect2:
	var row_step: float = BOX_SIZE.y + ROW_GAP
	var layer_step: float = BOX_SIZE.x + LAYER_GAP
	var count: int = _graph.layer_rows[layer] if layer < _graph.layer_rows.size() else 1
	var y_shift: float = (_graph.max_rows - count) * row_step * 0.5
	return Rect2(Vector2(MARGIN + layer * layer_step, MARGIN + y_shift + row * row_step), BOX_SIZE)


func _step_to(raw: Array[Vector2], from: Vector2, to: Vector2) -> void:
	var mid_x: float = (from.x + to.x) * 0.5
	raw.append(Vector2(mid_x, from.y))
	raw.append(Vector2(mid_x, to.y))


func _route_self_loop(rect: Rect2) -> PackedVector2Array:
	var inset: float = BOX_SIZE.x * 0.25
	var top: float = rect.position.y - ROW_GAP * 0.4
	return PackedVector2Array([
		Vector2(rect.end.x - inset, rect.position.y),
		Vector2(rect.end.x - inset, top),
		Vector2(rect.position.x + inset, top),
		Vector2(rect.position.x + inset, rect.position.y),
	])


func _route_edge(from_rect: Rect2, to_rect: Rect2, is_back: bool, waypoints: Array[Vector2i]) -> PackedVector2Array:
	var start: Vector2 = Vector2(from_rect.end.x, from_rect.get_center().y)
	var finish: Vector2 = Vector2(to_rect.position.x, to_rect.get_center().y)
	var raw: Array[Vector2] = [start]
	if not is_back:
		var cursor: Vector2 = start
		for waypoint: Vector2i in waypoints:
			var slot: Rect2 = _slot_rect(waypoint.x, waypoint.y)
			var y: float = slot.get_center().y
			_step_to(raw, cursor, Vector2(slot.position.x, y))
			raw.append(Vector2(slot.position.x, y))
			cursor = Vector2(slot.end.x, y)
			raw.append(cursor)
		_step_to(raw, cursor, finish)
	else:
		var out_x: float = start.x + LAYER_GAP * 0.35
		var in_x: float = finish.x - LAYER_GAP * 0.35
		var below_y: float = maxf(from_rect.end.y, to_rect.end.y) + ROW_GAP * 0.5
		raw.append(Vector2(out_x, start.y))
		raw.append(Vector2(out_x, below_y))
		raw.append(Vector2(in_x, below_y))
		raw.append(Vector2(in_x, finish.y))
	raw.append(finish)

	var points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in raw:
		if points.is_empty() or not points[points.size() - 1].is_equal_approx(point):
			points.append(point)
	return points


func _to_screen(point: Vector2) -> Vector2:
	return point * _zoom + _offset


func _screen_rect(rect: Rect2) -> Rect2:
	return Rect2(_to_screen(rect.position), rect.size * _zoom)


func _box_at(point: Vector2) -> String:
	for id: String in _rects:
		if _screen_rect(_rects[id]).has_point(point):
			return id
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_dragging = true
				_drag_moved = false
				_press_pos = event.position
			elif _dragging:
				_dragging = false
				if not _drag_moved and event.button_index == MOUSE_BUTTON_LEFT:
					var id: String = _box_at(event.position)
					if id != "" and _clickable.get(id, false):
						box_activated.emit(id)
			accept_event()
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom_at(event.position, ZOOM_STEP)
			accept_event()
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom_at(event.position, 1.0 / ZOOM_STEP)
			accept_event()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _dragging:
		if not _drag_moved and event.position.distance_to(_press_pos) > DRAG_THRESHOLD:
			_drag_moved = true
		if _drag_moved:
			_offset += event.relative
			queue_redraw()
		return

	var id: String = _box_at(event.position)
	if id != _hover_id:
		_hover_id = id
		var clickable: bool = _hover_id != "" and _clickable.get(_hover_id, false)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
		queue_redraw()


func _zoom_at(pivot: Vector2, factor: float) -> void:
	var old_zoom: float = _zoom
	_zoom = clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(old_zoom, _zoom):
		return
	_offset = pivot - (pivot - _offset) * (_zoom / old_zoom)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	if _graph == null:
		return

	for line: Dictionary in _edge_lines:
		_draw_edge(line)

	var font: Font = get_theme_font(&"font", &"Label")
	for id: String in _graph.box_ids:
		if not _rects.has(id):
			continue
		_draw_box(id, font)


func _draw_edge(line: Dictionary) -> void:
	var points: PackedVector2Array = line["points"]
	var color: Color = line["color"]
	var width: float = float(line["width"]) * _zoom
	var screen_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		screen_points.append(_to_screen(point))
	draw_polyline(screen_points, color, width, true)

	var tip: Vector2 = screen_points[screen_points.size() - 1]
	var direction: Vector2 = Vector2.RIGHT
	if screen_points.size() > 1:
		direction = (tip - screen_points[screen_points.size() - 2]).normalized()
	var side: Vector2 = direction.orthogonal()
	var arrow: float = ARROW_SIZE * _zoom
	var head: PackedVector2Array = PackedVector2Array([
		tip,
		tip - direction * arrow + side * arrow * 0.55,
		tip - direction * arrow - side * arrow * 0.55,
	])
	draw_colored_polygon(head, color)


func _draw_box(id: String, font: Font) -> void:
	var box: VNEngineFlowGraph.Box = _graph.boxes[id]
	var rect: Rect2 = _screen_rect(_rects[id])
	var reached: bool = _reached.get(id, false)
	var is_current: bool = id == _current_box
	var hovered: bool = id == _hover_id and _clickable.get(id, false)
	var radius: int = maxi(2, int(CORNER_RADIUS * _zoom))
	var border: int = maxi(1, int(2.0 * _zoom))

	if is_current:
		var glow_pad: float = 6.0 * _zoom
		_box_style.bg_color = BOX_GLOW_CURRENT
		_box_style.border_color = Color.TRANSPARENT
		_box_style.set_border_width_all(0)
		_box_style.set_corner_radius_all(radius + int(glow_pad))
		draw_style_box(_box_style, rect.grow(glow_pad))

	_box_style.bg_color = BOX_BG if reached else BOX_BG_LOCKED
	if is_current:
		_box_style.border_color = BOX_BORDER_CURRENT
	elif hovered:
		_box_style.border_color = BOX_BORDER_HOVER
	else:
		_box_style.border_color = BOX_BORDER if reached else BOX_BORDER_LOCKED
	_box_style.set_border_width_all(border)
	_box_style.set_corner_radius_all(radius)
	draw_style_box(_box_style, rect)

	var strip_color: Color = _strip_color(box)
	if not reached:
		strip_color.a *= LOCKED_ALPHA
	_strip_style.bg_color = strip_color
	_strip_style.corner_radius_top_left = radius
	_strip_style.corner_radius_bottom_left = radius
	var strip_rect: Rect2 = Rect2(rect.position + Vector2(border, border), Vector2(STRIP_WIDTH * _zoom, rect.size.y - border * 2))
	draw_style_box(_strip_style, strip_rect)

	var text_left: float = rect.position.x + (STRIP_WIDTH + 12.0) * _zoom
	var text_width: float = rect.end.x - 12.0 * _zoom - text_left
	var title_size: int = maxi(8, int(TITLE_FONT_SIZE * _zoom))
	var kind_size: int = maxi(6, int(KIND_FONT_SIZE * _zoom))
	var center_y: float = rect.get_center().y
	var title: String = box.title if reached else _locked_text
	var title_color: Color = TEXT_COLOR if reached else TEXT_LOCKED

	var kind_text: String = _kind_text(box)
	if kind_text == "":
		var baseline: float = center_y + (font.get_ascent(title_size) - font.get_descent(title_size)) * 0.5
		_draw_fitted(font, Vector2(text_left, baseline), title, title_size, text_width, title_color)
		return

	var kind_color: Color = TEXT_KIND if reached else TEXT_LOCKED
	var kind_baseline: float = center_y - 4.0 * _zoom
	_draw_fitted(font, Vector2(text_left, kind_baseline), kind_text, kind_size, text_width, kind_color)
	var title_baseline: float = center_y + font.get_ascent(title_size) - 2.0 * _zoom
	_draw_fitted(font, Vector2(text_left, title_baseline), title, title_size, text_width, title_color)


func _draw_fitted(font: Font, pos: Vector2, text: String, font_size: int, max_width: float, color: Color) -> void:
	var fitted: String = text
	if font.get_string_size(fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
		var cut: int = text.length()
		fitted = "..."
		while cut > 1:
			cut -= 1
			var candidate: String = text.substr(0, cut).strip_edges() + "..."
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
				fitted = candidate
				break
	draw_string(font, pos, fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _strip_color(box: VNEngineFlowGraph.Box) -> Color:
	if box.kind == "ending" or box.chapter_index < 0:
		return ENDING_STRIP
	return CHAPTER_COLORS[box.chapter_index % CHAPTER_COLORS.size()]


func _kind_text(box: VNEngineFlowGraph.Box) -> String:
	match box.kind:
		"chapter":
			return "CHAPTER"
		"ending":
			return "ENDING"
	return ""
