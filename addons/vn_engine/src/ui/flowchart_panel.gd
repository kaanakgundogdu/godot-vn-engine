class_name VNEngineFlowchartPanel
extends ColorRect

signal closed

var _runner: VNEngineStoryRunner = null
var _graph: VNEngineFlowGraph = null

@onready var close_btn: Button = %CloseFlowchartButton
@onready var view: VNEngineFlowchartView = %FlowchartView
@onready var empty_label: Label = %EmptyLabel
@onready var hint_label: Label = %HintLabel


func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	view.box_activated.connect(_on_box_activated)


func set_runner(runner: VNEngineStoryRunner) -> void:
	_runner = runner


func open_panel() -> void:
	show()
	close_btn.grab_focus()

	var manifest: VNEngineGameManifest = VNEngineMain.game().get_manifest()
	var extras_def: VNEngineExtrasDef = manifest.get_extras() if manifest != null else VNEngineExtrasDef.new()
	_graph = VNEngineFlowGraph.build(manifest) if manifest != null else null

	var path: Array[String] = []
	var current: String = ""
	if _runner != null:
		path = _runner.state.flow_path.duplicate()
		if not path.is_empty():
			current = path.back()

	view.set_locked_text(extras_def.locked_name_text)
	view.set_graph(_graph, current, path)

	var is_empty: bool = _graph == null or _graph.box_ids.is_empty()
	empty_label.visible = is_empty
	view.visible = not is_empty
	hint_label.visible = not is_empty
	if is_empty:
		return

	if current != "":
		view.center_on(current)
	else:
		view.fit_all()


func _on_close_pressed() -> void:
	hide()
	closed.emit()


func _on_box_activated(box_id: String) -> void:
	var box: VNEngineFlowGraph.Box = _graph.boxes.get(box_id)
	if box == null:
		return

	var message: String = 'Start from "%s"?' % box.title
	if _runner != null:
		if VNEngineMain.settings().autosave:
			message += " Your progress is autosaved first."
		else:
			message += " Unsaved progress will be lost."

	var dialog: Control = VNEngineMain.game().open_overlay(&"confirm", {
		"message": message,
		"confirm_text": "Start",
		"cancel_text": "Cancel",
	})
	if dialog == null:
		return
	dialog.confirmed.connect(_on_start_confirmed.bind(box_id))


func _on_start_confirmed(box_id: String) -> void:
	VNEngineMain.game().start_from_flow(box_id)
