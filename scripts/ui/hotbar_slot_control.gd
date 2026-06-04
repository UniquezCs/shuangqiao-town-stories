extends PanelContainer

var owner_panel: Node = null
var slot_index := -1
var slot_data: Dictionary = {}
var selected := false


func setup(next_owner: Node, next_slot_index: int, next_slot_data: Dictionary, is_selected: bool) -> void:
	owner_panel = next_owner
	slot_index = next_slot_index
	slot_data = next_slot_data.duplicate()
	selected = is_selected
	_build_ui()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if slot_data.is_empty():
		return null
	var data := {
		"source": "hotbar",
		"slot_index": slot_index,
		"slot": slot_data.duplicate(),
	}
	set_drag_preview(_make_preview())
	return data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if owner_panel != null and owner_panel.has_method("can_drop_slot_data"):
		return bool(owner_panel.call("can_drop_slot_data", data, "hotbar", slot_index))
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if owner_panel != null and owner_panel.has_method("handle_slot_drop"):
		owner_panel.call("handle_slot_drop", data, "hotbar", slot_index)


func _build_ui() -> void:
	name = "HotbarSlot%d" % (slot_index + 1)
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(64, 64)
	_apply_slot_style()
	for child in get_children():
		child.queue_free()

	var key_label := Label.new()
	key_label.name = "HotbarKeyLabel"
	key_label.text = str(slot_index + 1)
	key_label.position = Vector2(5, 2)
	key_label.add_theme_font_size_override("font_size", 12)
	add_child(key_label)

	if slot_data.is_empty():
		return

	var item_id := str(slot_data.get("item_id", ""))
	var icon_texture := _load_item_icon(item_id)
	if icon_texture != null:
		var icon := TextureRect.new()
		icon.name = "HotbarIcon"
		icon.texture = icon_texture
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(14, 14)
		icon.custom_minimum_size = Vector2(36, 36)
		icon.size = Vector2(36, 36)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
	else:
		var name_label := Label.new()
		name_label.name = "HotbarItemName"
		name_label.text = ConfigLoader.get_item_name(item_id)
		name_label.position = Vector2(10, 22)
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(name_label)

	var count := int(slot_data.get("count", 0))
	if count > 1:
		var count_label := Label.new()
		count_label.name = "HotbarCountLabel"
		count_label.text = str(count)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.position = Vector2(38, 43)
		count_label.size = Vector2(20, 18)
		count_label.add_theme_font_size_override("font_size", 13)
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(count_label)


func _make_preview() -> Control:
	var preview := Label.new()
	preview.text = "%s x%d" % [ConfigLoader.get_item_name(str(slot_data.get("item_id", ""))), int(slot_data.get("count", 0))]
	preview.add_theme_font_size_override("font_size", 14)
	return preview


func _load_item_icon(item_id: String) -> Texture2D:
	var icon_path := ConfigLoader.get_item_icon(item_id)
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null
	return load(icon_path) as Texture2D


func _apply_slot_style() -> void:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.12, 0.11, 0.09, 0.86)
	stylebox.border_color = Color(0.2, 0.95, 0.35, 1.0) if selected else Color(0.43, 0.32, 0.18, 1.0)
	stylebox.set_border_width_all(3 if selected else 2)
	stylebox.corner_radius_top_left = 4
	stylebox.corner_radius_top_right = 4
	stylebox.corner_radius_bottom_left = 4
	stylebox.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", stylebox)
