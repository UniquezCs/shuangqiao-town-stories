extends Control

const HotbarSlotControl := preload("res://scripts/ui/hotbar_slot_control.gd")

var _slots_container: HBoxContainer


func _ready() -> void:
	_build_ui()
	SignalBus.hotbar_changed.connect(_on_hotbar_changed)
	_refresh()


func can_drop_slot_data(data: Variant, target_container: String, target_index: int) -> bool:
	if target_container != "hotbar" or typeof(data) != TYPE_DICTIONARY:
		return false
	var source := str((data as Dictionary).get("source", ""))
	return ["backpack", "hotbar"].has(source) and target_index >= 0 and target_index < Hotbar.slot_count


func handle_slot_drop(data: Variant, target_container: String, target_index: int) -> void:
	if not can_drop_slot_data(data, target_container, target_index):
		return
	var drag_data: Dictionary = data
	var source := str(drag_data.get("source", ""))
	if source == "hotbar":
		Hotbar.move_slot(int(drag_data.get("slot_index", -1)), target_index)
	elif source == "backpack":
		Hotbar.transfer_inventory_to_hotbar(int(drag_data.get("slot_index", -1)), target_index)
	_refresh()


func _build_ui() -> void:
	name = "HotbarPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -324.0
	offset_right = 324.0
	offset_top = -88.0
	offset_bottom = -18.0

	var background := PanelContainer.new()
	background.name = "HotbarBackground"
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.08, 0.07, 0.055, 0.82)
	stylebox.border_color = Color(0.34, 0.24, 0.13, 1.0)
	stylebox.set_border_width_all(2)
	stylebox.corner_radius_top_left = 6
	stylebox.corner_radius_top_right = 6
	stylebox.corner_radius_bottom_left = 6
	stylebox.corner_radius_bottom_right = 6
	background.add_theme_stylebox_override("panel", stylebox)
	add_child(background)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 3)
	background.add_child(margin)

	_slots_container = HBoxContainer.new()
	_slots_container.name = "HotbarSlots"
	_slots_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slots_container.add_theme_constant_override("separation", 7)
	margin.add_child(_slots_container)


func _on_hotbar_changed(_slots: Array, _selected_index: int) -> void:
	_refresh()


func _refresh() -> void:
	if _slots_container == null:
		return
	for child in _slots_container.get_children():
		_slots_container.remove_child(child)
		child.queue_free()
	var slots := Hotbar.get_slots_with_empty()
	for index in range(slots.size()):
		var slot := HotbarSlotControl.new()
		slot.setup(self, index, slots[index], index == Hotbar.selected_index)
		_slots_container.add_child(slot)
