extends CanvasLayer

var _shop: Node = null
var _panel: PanelContainer
var _apple_label: Label
var _seed_button: Button
var _apple_button: Button


func _ready() -> void:
	_build_ui()
	SignalBus.seed_shop_goods_changed.connect(_on_seed_shop_goods_changed)
	hide_panel()


func open(shop: Node) -> void:
	_shop = shop
	_update_labels()
	_panel.visible = true


func hide_panel() -> void:
	if _panel != null:
		_panel.visible = false
	_shop = null


func _unhandled_input(event: InputEvent) -> void:
	if _panel != null and _panel.visible and event.is_action_pressed("ui_cancel"):
		hide_panel()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(392, 328)
	_panel.custom_minimum_size = Vector2(280, 170)
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
	title.text = "小卖部"
	box.add_child(title)

	_apple_label = Label.new()
	box.add_child(_apple_label)

	_seed_button = Button.new()
	_seed_button.pressed.connect(func() -> void:
		if _shop != null and is_instance_valid(_shop):
			_shop.call("buy_seed")
		_update_labels()
	)
	box.add_child(_seed_button)

	_apple_button = Button.new()
	_apple_button.pressed.connect(func() -> void:
		if _shop != null and is_instance_valid(_shop):
			_shop.call("buy_apple")
		_update_labels()
	)
	box.add_child(_apple_button)

	var close := Button.new()
	close.text = "离开"
	close.pressed.connect(hide_panel)
	box.add_child(close)


func _on_seed_shop_goods_changed(_apple_price: int, _apple_stock: int) -> void:
	if _panel != null and _panel.visible:
		_update_labels()


func _update_labels() -> void:
	if _apple_label == null:
		return
	_apple_label.text = "今日苹果：%d 元 / 个，剩余 %d 个" % [
		GameState.seed_shop_apple_price,
		GameState.seed_shop_apple_stock,
	]
	_seed_button.text = "买苹果种子（%d 元）" % PrototypeConstants.SEED_PRICE
	_apple_button.text = "买苹果（%d 元）" % GameState.seed_shop_apple_price
	_apple_button.disabled = GameState.seed_shop_apple_stock <= 0
