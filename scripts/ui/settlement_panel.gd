extends CanvasLayer

var _panel: PanelContainer
var _content: Label


func _ready() -> void:
	_build_ui()
	SignalBus.settlement_ready.connect(show_result)
	hide_panel()


func show_result(result: Dictionary) -> void:
	var used_spots: Array = result.get("used_spots", [])
	_content.text = "\n".join([
		"结算",
		"收入：%d 元" % int(result.get("income", 0)),
		"现金：%d 元" % int(result.get("cash", 0)),
		"成交：%d 次" % int(result.get("sales", 0)),
		"均价：%.1f 元" % float(result.get("average_price", 0.0)),
		"拒买：%d 次" % int(result.get("rejections", 0)),
		"剩余苹果：%d" % int(result.get("remaining_apples", 0)),
		"地点：%s" % (", ".join(used_spots) if used_spots.size() > 0 else "无"),
		"评价：%s" % str(result.get("rating", "")),
	])
	_panel.visible = true


func hide_panel() -> void:
	if _panel != null:
		_panel.visible = false


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(650, 64)
	_panel.custom_minimum_size = Vector2(280, 270)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	margin.add_child(box)

	_content = Label.new()
	box.add_child(_content)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(hide_panel)
	box.add_child(close_button)
