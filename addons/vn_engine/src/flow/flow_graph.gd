class_name VNEngineFlowGraph
extends RefCounted

const BARYCENTER_ROUNDS := 4


class Box:
	var id: String
	var kind: String
	var title: String
	var chapter_id: String
	var chapter_index: int
	var layer: int
	var row: int


class Edge:
	var from_id: String
	var to_id: String
	var is_back: bool
	var waypoints: Array[Vector2i] = []


var boxes: Dictionary = {}
var box_ids: Array[String] = []
var edges: Array[Edge] = []
var layer_count: int = 0
var max_rows: int = 0
var layer_rows: Array[int] = []

var _edge_keys: Dictionary = {}
var _scripts: Dictionary = {}
var _manifest: VNEngineGameManifest = null


static func build(manifest: VNEngineGameManifest) -> VNEngineFlowGraph:
	var graph: VNEngineFlowGraph = VNEngineFlowGraph.new()
	if manifest == null:
		return graph
	graph._manifest = manifest
	graph._collect_boxes()
	graph._collect_edges()
	graph._layout()
	graph._scripts.clear()
	graph._edge_keys.clear()
	return graph


func outgoing(box_id: String) -> Array[Edge]:
	var result: Array[Edge] = []
	for edge in edges:
		if edge.from_id == box_id:
			result.append(edge)
	return result


func _add_box(id: String, kind: String, title: String, chapter_id: String, chapter_index: int) -> void:
	if boxes.has(id):
		return
	var box: Box = Box.new()
	box.id = id
	box.kind = kind
	box.title = title
	box.chapter_id = chapter_id
	box.chapter_index = chapter_index
	boxes[id] = box
	box_ids.append(id)


func _add_edge(from_id: String, to_id: String) -> void:
	if not boxes.has(from_id) or not boxes.has(to_id):
		return
	var key: String = from_id + ">" + to_id
	if _edge_keys.has(key):
		return
	_edge_keys[key] = true
	var edge: Edge = Edge.new()
	edge.from_id = from_id
	edge.to_id = to_id
	edges.append(edge)


func _script_chapter_id(script: VNEngineStoryScript, chapter: VNEngineChapterDef) -> String:
	if script.chapter_id != "":
		return script.chapter_id
	return chapter.id


func _flow_title(node: VNEngineStoryNode) -> String:
	for entry in node.commands:
		if entry.get("name", "") == "flow":
			return " ".join(VNEngineCommand.parse_quoted_args(entry.get("args", "")))
	return ""


func _has_flow(node: VNEngineStoryNode) -> bool:
	for entry in node.commands:
		if entry.get("name", "") == "flow":
			return true
	return false


func _collect_boxes() -> void:
	for i in _manifest.chapters.size():
		var chapter: VNEngineChapterDef = _manifest.chapters[i]
		if chapter == null or chapter.id == "":
			continue
		var chapter_title: String = chapter.title if chapter.title != "" else chapter.id.capitalize()
		_add_box("chapter:" + chapter.id, "chapter", chapter_title, chapter.id, i)
		var script: VNEngineStoryScript = VNEngineScenarioLoader.load_script(chapter.script_path, _manifest.flags)
		_scripts[chapter.id] = script
		var script_chapter: String = _script_chapter_id(script, chapter)
		for node in script.nodes:
			if not _has_flow(node):
				continue
			_add_box("%s.%s" % [script_chapter, node.base_id], "flow", _flow_title(node), chapter.id, i)
	for ending in _manifest.endings:
		if ending == null or ending.id == "":
			continue
		var ending_title: String = ending.title if ending.title != "" else ending.id
		_add_box("ending:" + ending.id, "ending", ending_title, "", -1)


func _collect_edges() -> void:
	for i in _manifest.chapters.size():
		var chapter: VNEngineChapterDef = _manifest.chapters[i]
		if chapter == null or not _scripts.has(chapter.id):
			continue
		var script: VNEngineStoryScript = _scripts[chapter.id]
		var script_chapter: String = _script_chapter_id(script, chapter)
		_walk(chapter, script, "chapter:" + chapter.id, 0, false)
		for node_index in script.nodes.size():
			var node: VNEngineStoryNode = script.nodes[node_index]
			if _has_flow(node):
				_walk(chapter, script, "%s.%s" % [script_chapter, node.base_id], node_index, true)


func _walk(chapter: VNEngineChapterDef, script: VNEngineStoryScript, from_id: String, start_index: int, skip_start: bool) -> void:
	var script_chapter: String = _script_chapter_id(script, chapter)
	var visited: Dictionary = {}
	var queue: Array[int] = []
	if skip_start and start_index >= 0 and start_index < script.nodes.size():
		queue.append_array(_successors(chapter, script, script.nodes[start_index], from_id))
	else:
		queue.append(start_index)
	while not queue.is_empty():
		var index: int = queue.pop_front()
		if index < 0 or index >= script.nodes.size():
			_exhausted(chapter, from_id)
			continue
		if visited.has(index):
			continue
		visited[index] = true
		var node: VNEngineStoryNode = script.nodes[index]
		if _has_flow(node):
			_add_edge(from_id, "%s.%s" % [script_chapter, node.base_id])
			continue
		queue.append_array(_successors(chapter, script, node, from_id))


func _successors(chapter: VNEngineChapterDef, script: VNEngineStoryScript, node: VNEngineStoryNode, from_id: String) -> Array[int]:
	var result: Array[int] = []
	if not node.choices.is_empty():
		for choice in node.choices:
			if choice.target_index != -1:
				result.append(choice.target_index)
		return result
	for entry in node.commands:
		var cname: String = entry.get("name", "")
		var args: String = String(entry.get("args", "")).strip_edges()
		match cname:
			"jump":
				_append_label(result, script, args)
				return result
			"jump_if":
				if args.contains("->"):
					_append_label(result, script, args.split("->", true, 1)[1].strip_edges())
			"call":
				_append_label(result, script, args)
			"end":
				_end_edges(from_id, args)
				return result
			"goto_chapter":
				if _manifest.find_chapter(args) != null:
					_add_edge(from_id, "chapter:" + _manifest.find_chapter(args).id)
				return result
			"return", "scene", "credits":
				return result
	if node.next_index == -1:
		_exhausted(chapter, from_id)
	else:
		result.append(node.next_index)
	return result


func _append_label(result: Array[int], script: VNEngineStoryScript, label: String) -> void:
	var index: int = script.index_of(label)
	if index != -1:
		result.append(index)


func _end_edges(from_id: String, ending_id: String) -> void:
	if ending_id != "":
		_add_ending_edge(from_id, ending_id)
		return
	for ending in _manifest.endings:
		if ending != null and ending.condition != "":
			_add_ending_edge(from_id, ending.id)
	_add_ending_edge(from_id, _manifest.default_ending)


func _add_ending_edge(from_id: String, ending_id: String) -> void:
	var ending: VNEngineEndingDef = _manifest.find_ending(ending_id)
	if ending != null:
		_add_edge(from_id, "ending:" + ending.id)


func _exhausted(chapter: VNEngineChapterDef, from_id: String) -> void:
	for branch in chapter.branches:
		if branch == null:
			continue
		var target: VNEngineChapterDef = _manifest.find_chapter(branch.chapter_id)
		if target != null:
			_add_edge(from_id, "chapter:" + target.id)
	var next: VNEngineChapterDef = _manifest.find_chapter(chapter.next_chapter)
	if next != null:
		_add_edge(from_id, "chapter:" + next.id)
	else:
		_add_ending_edge(from_id, _manifest.default_ending)


func _layout() -> void:
	if box_ids.is_empty():
		return
	_mark_back_edges()
	_assign_layers()
	_order_rows()


func _mark_back_edges() -> void:
	var state: Dictionary = {}
	var first_id: String = "chapter:" + _manifest.first_chapter
	if boxes.has(first_id):
		_dfs(first_id, state)
	for id in box_ids:
		if not state.has(id):
			_dfs(id, state)


func _dfs(id: String, state: Dictionary) -> void:
	state[id] = 1
	for edge in outgoing(id):
		var mark: int = state.get(edge.to_id, 0)
		if mark == 1:
			edge.is_back = true
		elif mark == 0:
			_dfs(edge.to_id, state)
	state[id] = 2


func _assign_layers() -> void:
	var indegree: Dictionary = {}
	for id in box_ids:
		indegree[id] = 0
		boxes[id].layer = 0
	for edge in edges:
		if not edge.is_back:
			indegree[edge.to_id] += 1
	var ready: Array[String] = []
	for id in box_ids:
		if indegree[id] == 0:
			ready.append(id)
	while not ready.is_empty():
		var id: String = ready.pop_front()
		var box: Box = boxes[id]
		for edge in outgoing(id):
			if edge.is_back:
				continue
			var target: Box = boxes[edge.to_id]
			target.layer = maxi(target.layer, box.layer + 1)
			indegree[edge.to_id] -= 1
			if indegree[edge.to_id] == 0:
				ready.append(edge.to_id)
	layer_count = 0
	for id in box_ids:
		layer_count = maxi(layer_count, boxes[id].layer + 1)


func _order_rows() -> void:
	var layers: Array = []
	for i in layer_count:
		var layer_ids: Array[String] = []
		layers.append(layer_ids)
	var slots: Dictionary = {}
	for id in box_ids:
		layers[boxes[id].layer].append(id)
		slots[id] = boxes[id].layer

	var chains: Array = []
	var links: Array = []
	for i in edges.size():
		var edge: Edge = edges[i]
		var chain: Array[String] = [edge.from_id]
		if not edge.is_back:
			for layer in range(boxes[edge.from_id].layer + 1, boxes[edge.to_id].layer):
				var dummy: String = "~%d.%d" % [i, layer]
				layers[layer].append(dummy)
				slots[dummy] = layer
				chain.append(dummy)
		chain.append(edge.to_id)
		chains.append(chain)
		for j in range(chain.size() - 1):
			links.append([chain[j], chain[j + 1]])

	var rows: Dictionary = {}
	for layer_ids in layers:
		for row in layer_ids.size():
			rows[layer_ids[row]] = row
	for _round in BARYCENTER_ROUNDS:
		for i in range(1, layer_count):
			_sort_layer(layers[i], slots, rows, links, true)
		for i in range(layer_count - 2, -1, -1):
			_sort_layer(layers[i], slots, rows, links, false)

	layer_rows.clear()
	max_rows = 0
	for layer_ids in layers:
		layer_rows.append(layer_ids.size())
		max_rows = maxi(max_rows, layer_ids.size())
	for id in box_ids:
		boxes[id].row = rows[id]
	for i in edges.size():
		var chain: Array[String] = chains[i]
		edges[i].waypoints.clear()
		for j in range(1, chain.size() - 1):
			edges[i].waypoints.append(Vector2i(slots[chain[j]], rows[chain[j]]))


func _sort_layer(layer_ids: Array[String], slots: Dictionary, rows: Dictionary, links: Array, downward: bool) -> void:
	var weights: Dictionary = {}
	for id in layer_ids:
		weights[id] = _barycenter(id, slots, rows, links, downward)
	layer_ids.sort_custom(func(a: String, b: String) -> bool:
		if weights[a] == weights[b]:
			return rows[a] < rows[b]
		return weights[a] < weights[b])
	for row in layer_ids.size():
		rows[layer_ids[row]] = row


func _barycenter(id: String, slots: Dictionary, rows: Dictionary, links: Array, downward: bool) -> float:
	var layer: int = slots[id]
	var total: float = 0.0
	var count: int = 0
	for link in links:
		var other_id: String = ""
		if link[1] == id:
			other_id = link[0]
		elif link[0] == id:
			other_id = link[1]
		else:
			continue
		var other_layer: int = slots[other_id]
		if downward and other_layer >= layer:
			continue
		if not downward and other_layer <= layer:
			continue
		total += float(rows[other_id])
		count += 1
	if count == 0:
		return float(rows[id])
	return total / float(count)
