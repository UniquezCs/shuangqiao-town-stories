extends CanvasLayer

var _panel: PanelContainer
var _summary_label: Label
var _defer_next_summary := false
var _pending_summary: Dictionary = {}


func _ready() -> void:
	_build_ui()
	SignalBus.daily_summary_ready.connect(_on_daily_summary_ready)
	hide_panel()


func _unhandled_input(event: InputEvent) -> void:
	if _panel.visible and event.is_action_pressed("ui_cancel"):
		hide_panel()
		get_viewport().set_input_as_handled()


func hide_panel() -> void:
	_panel.visible = false


func defer_next_summary() -> void:
	_defer_next_summary = true
	_pending_summary = {}
	hide_panel()


func show_pending_summary() -> void:
	if _pending_summary.is_empty():
		_defer_next_summary = false
		return
	var result := _pending_summary.duplicate(true)
	_pending_summary = {}
	_defer_next_summary = false
	_show_summary(result)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(760, 244)
	_panel.custom_minimum_size = Vector2(420, 280)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	margin.add_child(box)

	var title := Label.new()
	title.text = "昨日总结"
	box.add_child(title)

	_summary_label = Label.new()
	box.add_child(_summary_label)

	var close := Button.new()
	close.text = "继续"
	close.pressed.connect(hide_panel)
	box.add_child(close)


func _on_daily_summary_ready(result: Dictionary) -> void:
	if _defer_next_summary:
		_pending_summary = result.duplicate(true)
		return
	_show_summary(result)


func _show_summary(result: Dictionary) -> void:
	_summary_label.text = "第 %d 天\n收入：%d 元\n卖出商品：%d 个\n接待顾客：%d 人\n拒绝/错过：%d 人\n被城管抓到：%d 次\n罚款：%d 元" % [
		int(result.get("day", 1)),
		int(result.get("income", 0)),
		int(result.get("sales", 0)),
		int(result.get("customers", 0)),
		int(result.get("missed_or_rejected", 0)),
		int(result.get("chengguan_caught", 0)),
		int(result.get("chengguan_fines", 0)),
	]
	_panel.visible = true
