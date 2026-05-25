extends CanvasLayer

signal price_confirmed(price: int)

var _panel: PanelContainer
var _price_label: Label
var _price := 2


func _ready() -> void:
	_build_ui()
	hide_panel()


func open(default_price: int = 2) -> void:
	_price = clamp(default_price, PrototypeConstants.MIN_APPLE_PRICE, PrototypeConstants.MAX_APPLE_PRICE)
	_update_label()
	_panel.visible = true
	get_tree().paused = true


func hide_panel() -> void:
	if _panel != null:
		_panel.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if _panel != null and _panel.visible and event.is_action_pressed("ui_cancel"):
		hide_panel()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.position = Vector2(392, 170)
	_panel.custom_minimum_size = Vector2(260, 150)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	margin.add_child(box)

	var title := Label.new()
	title.text = "苹果定价"
	box.add_child(title)

	_price_label = Label.new()
	box.add_child(_price_label)

	var row := HBoxContainer.new()
	box.add_child(row)

	var minus := Button.new()
	minus.text = "-1"
	minus.pressed.connect(func() -> void:
		_price = max(PrototypeConstants.MIN_APPLE_PRICE, _price - 1)
		_update_label()
	)
	row.add_child(minus)

	var plus := Button.new()
	plus.text = "+1"
	plus.pressed.connect(func() -> void:
		_price = min(PrototypeConstants.MAX_APPLE_PRICE, _price + 1)
		_update_label()
	)
	row.add_child(plus)

	var confirm := Button.new()
	confirm.text = "开卖"
	confirm.pressed.connect(func() -> void:
		price_confirmed.emit(_price)
		hide_panel()
	)
	box.add_child(confirm)

	var cancel := Button.new()
	cancel.text = "取消"
	cancel.pressed.connect(hide_panel)
	box.add_child(cancel)


func _update_label() -> void:
	_price_label.text = "单价：%d 元 / 个" % _price
