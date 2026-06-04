extends CanvasLayer

const InventorySlotControl := preload("res://scripts/ui/inventory_slot_control.gd")
const BACKPACK_PANEL_TEXTURE_PATH := "res://assets/generated/sprites/ui/panels/backpack_panel_360x420.png"

var _panel: PanelContainer
var _grid: GridContainer
var _title: Label
var _dragging := false


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
	_apply_panel_style(_panel, BACKPACK_PANEL_TEXTURE_PATH)
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
	_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_title.gui_input.connect(_on_drag_handle_gui_input)
	box.add_child(_title)

	_grid = GridContainer.new()
	_grid.columns = 4
	box.add_child(_grid)


func _on_backpack_changed(_slots: Array, _slot_count: int) -> void:
	if _panel != null and _panel.visible:
		_refresh()


func _refresh() -> void:
	_title.text = "背包 %d / %d 格" % [Inventory.occupied_slot_count(), Inventory.slot_count]
	for child in _grid.get_children():
		child.queue_free()
	var slots := Inventory.get_slots_with_empty()
	for index in range(slots.size()):
		_grid.add_child(_make_slot(index, slots[index]))


func _make_slot(index: int, slot: Dictionary) -> Control:
	var panel := InventorySlotControl.new()
	panel.setup(self, "backpack", index, slot)
	return panel


func get_panel_position() -> Vector2:
	return _panel.position if _panel != null else Vector2.ZERO


func move_panel_by(delta: Vector2) -> void:
	if _panel == null:
		return
	_panel.position += delta


func _on_drag_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		get_viewport().set_input_as_handled()
	elif _dragging and event is InputEventMouseMotion:
		move_panel_by(event.relative)
		get_viewport().set_input_as_handled()


func _apply_panel_style(panel: PanelContainer, texture_path: String) -> void:
	if panel == null or not ResourceLoader.exists(texture_path):
		return
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return
	var stylebox := StyleBoxTexture.new()
	stylebox.texture = texture
	panel.add_theme_stylebox_override("panel", stylebox)


func can_drop_slot_data(data: Variant, target_container: String, _target_index: int) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return ["backpack", "hotbar"].has(str((data as Dictionary).get("source", ""))) and target_container == "backpack"


func handle_slot_drop(data: Variant, target_container: String, target_index: int) -> void:
	if not can_drop_slot_data(data, target_container, target_index):
		return
	var drag_data: Dictionary = data
	var source := str(drag_data.get("source", ""))
	if source == "backpack":
		Inventory.move_slot(int(drag_data.get("slot_index", -1)), target_index)
	elif source == "hotbar":
		Hotbar.transfer_hotbar_to_inventory(int(drag_data.get("slot_index", -1)), target_index)
	_refresh()
