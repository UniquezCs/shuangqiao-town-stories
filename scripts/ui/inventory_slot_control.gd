extends PanelContainer

const BACKPACK_SLOT_TEXTURE_PATH := "res://assets/generated/sprites/ui/slots/backpack_slot_78x72.png"
const STALL_SLOT_TEXTURE_PATH := "res://assets/generated/sprites/ui/slots/stall_slot_78x72.png"

var owner_panel: Node = null
var container_id := ""
var slot_index := -1
var slot_data: Dictionary = {}


func setup(next_owner: Node, next_container_id: String, next_slot_index: int, next_slot_data: Dictionary) -> void:
	owner_panel = next_owner
	container_id = next_container_id
	slot_index = next_slot_index
	slot_data = next_slot_data.duplicate()
	_build_ui()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if slot_data.is_empty():
		return null
	var data := {
		"source": container_id,
		"slot_index": slot_index,
		"slot": slot_data.duplicate(),
	}
	set_drag_preview(_make_preview())
	return data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if owner_panel != null and owner_panel.has_method("can_drop_slot_data"):
		return bool(owner_panel.call("can_drop_slot_data", data, container_id, slot_index))
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if owner_panel != null and owner_panel.has_method("handle_slot_drop"):
		owner_panel.call("handle_slot_drop", data, container_id, slot_index)


func _build_ui() -> void:
	custom_minimum_size = Vector2(78, 72)
	_apply_slot_style()
	for child in get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	if slot_data.is_empty():
		var empty_label := Label.new()
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.text = "空"
		margin.add_child(empty_label)
		return

	var item_id := str(slot_data.get("item_id", ""))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)

	var icon_texture := _load_item_icon(item_id)
	if icon_texture != null:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(42, 38)
		icon.texture = icon_texture
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(icon)
	else:
		var name_label := Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.text = ConfigLoader.get_item_name(item_id)
		box.add_child(name_label)

	var count_label := Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.text = "x%d" % int(slot_data.get("count", 0))
	box.add_child(count_label)

	if slot_data.has("price"):
		var price_label := Label.new()
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.text = "%d 元" % int(slot_data.get("price", 0))
		box.add_child(price_label)


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
	var texture_path := STALL_SLOT_TEXTURE_PATH if container_id == "stall" else BACKPACK_SLOT_TEXTURE_PATH
	if not ResourceLoader.exists(texture_path):
		return
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return
	var stylebox := StyleBoxTexture.new()
	stylebox.texture = texture
	add_theme_stylebox_override("panel", stylebox)
