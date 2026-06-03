extends CanvasLayer

signal stall_selected(stall_spot: Node)
signal begging_selected(stall_spot: Node)

var _stall_spot: Node = null
var _root: PanelContainer = null


func _ready() -> void:
	layer = 12
	_build_ui()
	hide_panel()


func open(stall_spot: Node) -> void:
	_stall_spot = stall_spot
	visible = true


func hide_panel() -> void:
	visible = false
	_stall_spot = null


func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = Vector2(240, 128)
	_root.size = Vector2(240, 128)
	_root.position = -_root.size * 0.5
	add_child(_root)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_root.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var title := Label.new()
	title.text = "选择经营方式"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var stall_button := Button.new()
	stall_button.text = "摆摊"
	stall_button.pressed.connect(_select_stall)
	column.add_child(stall_button)

	var begging_button := Button.new()
	begging_button.text = "乞讨"
	begging_button.pressed.connect(_select_begging)
	column.add_child(begging_button)

	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.pressed.connect(hide_panel)
	column.add_child(cancel_button)


func _select_stall() -> void:
	var spot := _stall_spot
	hide_panel()
	if spot != null and is_instance_valid(spot):
		stall_selected.emit(spot)


func _select_begging() -> void:
	var spot := _stall_spot
	hide_panel()
	if spot != null and is_instance_valid(spot):
		begging_selected.emit(spot)
