extends CanvasLayer

var _panel: PanelContainer
var _grid: GridContainer
var _title: Label


func _ready() -> void:
	_build_ui()
	SignalBus.backpack_changed.connect(_on_backpack_changed)
	hide_panel()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_backpack"):
		toggle()
		get_viewport().set_input_as_handled()
	elif _panel.visible and event.is_action_pressed("ui_cancel"):
		hide_panel()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if _panel.visible:
		hide_panel()
	else:
		open()


func open() -> void:
	_refresh()
	_panel.visible = true


func hide_panel() -> void:
	_panel.visible = false


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(1420, 72)
	_panel.custom_minimum_size = Vector2(360, 420)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	margin.add_child(box)

	_title = Label.new()
	box.add_child(_title)

	_grid = GridContainer.new()
	_grid.columns = 4
	box.add_child(_grid)


func _on_backpack_changed(_slots: Array, _slot_count: int) -> void:
	if _panel != null and _panel.visible:
		_refresh()


func _refresh() -> void:
	_title.text = "背包 %d / %d 格" % [Inventory.slots.size(), Inventory.slot_count]
	for child in _grid.get_children():
		child.queue_free()
	for slot in Inventory.get_slots_with_empty():
		_grid.add_child(_make_slot(slot))


func _make_slot(slot: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(78, 72)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	if slot.is_empty():
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text = "空"
		margin.add_child(label)
	else:
		var item_id := str(slot.get("item_id", ""))
		var icon_texture := _load_item_icon(item_id)
		if icon_texture != null:
			var box := VBoxContainer.new()
			box.alignment = BoxContainer.ALIGNMENT_CENTER
			margin.add_child(box)

			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(42, 38)
			icon.texture = icon_texture
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			box.add_child(icon)

			var count_label := Label.new()
			count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count_label.text = "x%d" % int(slot.get("count", 0))
			box.add_child(count_label)
		else:
			var label := Label.new()
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.text = "%s\nx%d" % [ConfigLoader.get_item_name(item_id), int(slot.get("count", 0))]
			margin.add_child(label)
	return panel


func _load_item_icon(item_id: String) -> Texture2D:
	var icon_path := ConfigLoader.get_item_icon(item_id)
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null
	return load(icon_path) as Texture2D
