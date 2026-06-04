extends CanvasLayer

var _ticket: Node = null
var _panel: PanelContainer
var _status_label: Label
var _digit_boxes: Array[SpinBox] = []
var _buy_button: Button
var _claim_button: Button


func _ready() -> void:
	layer = 12
	_build_ui()
	SignalBus.lottery_ticket_changed.connect(_on_lottery_ticket_changed)
	hide_panel()


func open(ticket: Node) -> void:
	_ticket = ticket
	_update_view()
	_panel.visible = true


func hide_panel() -> void:
	if _panel != null:
		_panel.visible = false
	_ticket = null


func _unhandled_input(event: InputEvent) -> void:
	if _panel != null and _panel.visible and event.is_action_pressed("ui_cancel"):
		hide_panel()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Root"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(360, 220)
	_panel.size = Vector2(360, 220)
	_panel.position = -_panel.size * 0.5
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var title := Label.new()
	title.text = "福利彩票"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status_label)

	var digits_row := HBoxContainer.new()
	digits_row.add_theme_constant_override("separation", 8)
	column.add_child(digits_row)
	for index in range(3):
		var spin_box := SpinBox.new()
		spin_box.min_value = 0
		spin_box.max_value = 9
		spin_box.step = 1
		spin_box.value = index
		spin_box.allow_greater = false
		spin_box.allow_lesser = false
		spin_box.custom_minimum_size = Vector2(88, 32)
		_digit_boxes.append(spin_box)
		digits_row.add_child(spin_box)

	_buy_button = Button.new()
	_buy_button.pressed.connect(_buy_ticket)
	column.add_child(_buy_button)

	_claim_button = Button.new()
	_claim_button.pressed.connect(_claim_or_close_result)
	column.add_child(_claim_button)

	var close_button := Button.new()
	close_button.text = "离开"
	close_button.pressed.connect(hide_panel)
	column.add_child(close_button)


func _update_view() -> void:
	if _ticket == null or not is_instance_valid(_ticket):
		return
	if _ticket.has_method("resolve_pending_if_due"):
		_ticket.call("resolve_pending_if_due")
	_status_label.text = str(_ticket.call("get_status_text")) if _ticket.has_method("get_status_text") else "今日彩票：10 元一张。"

	var ticket_data: Dictionary = _ticket.call("get_ticket") if _ticket.has_method("get_ticket") else {}
	var has_ticket: bool = typeof(ticket_data) == TYPE_DICTIONARY and not ticket_data.is_empty()
	var status: String = str(ticket_data.get("status", "")) if has_ticket else ""
	var cash_enough: bool = GameState.cash >= 10
	var can_buy: bool = not has_ticket and cash_enough

	for spin_box in _digit_boxes:
		spin_box.editable = can_buy
	_buy_button.text = "买一张（10 元）"
	_buy_button.disabled = not can_buy
	if has_ticket:
		_buy_button.text = "今天只能买一张"
	elif not cash_enough:
		_buy_button.text = "钱不够（10 元）"

	var prize := int(ticket_data.get("prize", 0)) if has_ticket else 0
	_claim_button.visible = status == "drawn"
	_claim_button.text = "兑奖 %d 元" % prize if prize > 0 else "收起未中奖彩票"


func _buy_ticket() -> void:
	if _ticket == null or not is_instance_valid(_ticket):
		return
	var digits := []
	for spin_box in _digit_boxes:
		digits.append(int(spin_box.value))
	if _ticket.has_method("buy_ticket"):
		_ticket.call("buy_ticket", digits)
	_update_view()


func _claim_or_close_result() -> void:
	if _ticket == null or not is_instance_valid(_ticket):
		return
	if _ticket.has_method("claim_or_close_result"):
		_ticket.call("claim_or_close_result")
	_update_view()


func _on_lottery_ticket_changed(_ticket_data: Dictionary) -> void:
	if _panel != null and _panel.visible:
		_update_view()
