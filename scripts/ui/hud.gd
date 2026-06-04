extends CanvasLayer

const HotbarPanelScript := preload("res://scripts/ui/hotbar_panel.gd")

var _cash_label: Label
var _objective_label: Label
var _window_label: Label
var _clock_label: Label
var _day_label: Label
var _prompt_label: Label
var _feedback_label: Label
var _hotbar_panel: Control


func _ready() -> void:
	_build_ui()
	SignalBus.cash_changed.connect(_on_cash_changed)
	SignalBus.inventory_changed.connect(_on_inventory_changed)
	SignalBus.objective_changed.connect(_on_objective_changed)
	SignalBus.time_window_changed.connect(_on_time_window_changed)
	SignalBus.game_time_changed.connect(_on_game_time_changed)
	SignalBus.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	SignalBus.sale_feedback.connect(_on_sale_feedback)

	_on_cash_changed(GameState.cash)
	_on_inventory_changed(PrototypeConstants.ITEM_APPLE, Inventory.get_count(PrototypeConstants.ITEM_APPLE))
	_on_inventory_changed(PrototypeConstants.ITEM_APPLE_SEED, Inventory.get_count(PrototypeConstants.ITEM_APPLE_SEED))
	_on_objective_changed(GameState.objective)
	_on_time_window_changed(GameState.current_time_window)
	_on_game_time_changed(GameState.current_game_minute, GameState.format_game_time(GameState.current_game_minute))


func _build_ui() -> void:
	var root := Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(360, 104)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	margin.add_child(box)

	_cash_label = Label.new()
	_day_label = Label.new()
	_clock_label = Label.new()
	_window_label = Label.new()
	_objective_label = Label.new()
	for label in [_cash_label, _day_label, _clock_label, _window_label, _objective_label]:
		box.add_child(label)

	_prompt_label = Label.new()
	_prompt_label.position = Vector2(16, 238)
	_prompt_label.add_theme_font_size_override("font_size", 20)
	root.add_child(_prompt_label)

	_feedback_label = Label.new()
	_feedback_label.position = Vector2(16, 202)
	_feedback_label.add_theme_font_size_override("font_size", 18)
	root.add_child(_feedback_label)

	_make_mouse_passthrough(root)
	_hotbar_panel = HotbarPanelScript.new()
	root.add_child(_hotbar_panel)


func _on_cash_changed(amount: int) -> void:
	_cash_label.text = "现金：%d 元" % amount


func _on_inventory_changed(item_id: String, count: int) -> void:
	pass


func _on_objective_changed(text: String) -> void:
	_objective_label.text = "目标：%s" % text


func _on_time_window_changed(window_id: String) -> void:
	_window_label.text = "营业阶段：%s" % PrototypeConstants.WINDOW_LABELS.get(window_id, window_id)


func _on_game_time_changed(_total_minutes: int, clock_text: String) -> void:
	_day_label.text = "第 %d 天" % GameState.day_index
	_clock_label.text = "时间：%s" % clock_text


func _on_interaction_prompt_changed(text: String) -> void:
	if text.is_empty():
		_prompt_label.text = ""
	elif text.begins_with("E：") or text.begins_with("左键："):
		_prompt_label.text = text
	else:
		_prompt_label.text = "E：%s" % text


func _on_sale_feedback(text: String, _world_position: Vector2) -> void:
	_feedback_label.text = text
	var tween := create_tween()
	_feedback_label.modulate.a = 1.0
	tween.tween_property(_feedback_label, "modulate:a", 0.0, 1.4).set_delay(0.6)


func _make_mouse_passthrough(node: Node) -> void:
	var control := node as Control
	if control != null:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_make_mouse_passthrough(child)
