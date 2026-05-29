extends Control

const CARD_SIZE := Vector2(260, 150)
const PREVIEW_SIZE := Vector2(72, 72)
const STATUS_COLORS := {
	"implemented": Color(0.50, 0.90, 0.58),
	"available": Color(0.54, 0.72, 1.0),
	"placeholder": Color(1.0, 0.78, 0.38),
	"missing": Color(1.0, 0.42, 0.42),
}

var _summary_label: Label
var _sections_box: VBoxContainer


func _ready() -> void:
	ConfigLoader.load_all()
	_build_ui()
	_populate()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_top", 20)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_bottom", 20)
	add_child(root)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	root.add_child(layout)

	var title := Label.new()
	title.text = "Asset Preview Scene"
	title.add_theme_font_size_override("font_size", 28)
	layout.add_child(title)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_summary_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	_sections_box = VBoxContainer.new()
	_sections_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sections_box.add_theme_constant_override("separation", 16)
	scroll.add_child(_sections_box)


func _populate() -> void:
	var status_counts: Dictionary = {}
	var entries := _collect_registry_entries(ConfigLoader.assets)
	for entry in entries:
		var status := str(entry.get("status", "unknown"))
		status_counts[status] = int(status_counts.get(status, 0)) + 1

	_summary_label.text = "Registered assets: %d | implemented: %d | available: %d | placeholder: %d | missing: %d" % [
		entries.size(),
		int(status_counts.get("implemented", 0)),
		int(status_counts.get("available", 0)),
		int(status_counts.get("placeholder", 0)),
		int(status_counts.get("missing", 0)),
	]

	var grouped: Dictionary = {}
	for entry in entries:
		var section := str(entry.get("_section", "other"))
		if not grouped.has(section):
			grouped[section] = []
		grouped[section].append(entry)

	for section in grouped.keys():
		_sections_box.add_child(_make_section(str(section), grouped[section]))


func _collect_registry_entries(root: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for section in root.keys():
		var value: Variant = root[section]
		if typeof(value) == TYPE_DICTIONARY:
			_collect_entries_recursive(value, str(section), entries)
	return entries


func _collect_entries_recursive(value: Variant, section: String, entries: Array[Dictionary]) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		var dict := value as Dictionary
		if dict.has("status") and dict.has("type"):
			var entry := dict.duplicate(true)
			entry["_section"] = section
			entries.append(entry)
			return
		for key in dict.keys():
			_collect_entries_recursive(dict[key], section, entries)
	elif typeof(value) == TYPE_ARRAY:
		for item in value:
			_collect_entries_recursive(item, section, entries)


func _make_section(section_name: String, entries: Array) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "%s (%d)" % [section_name, entries.size()]
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)

	for entry in entries:
		grid.add_child(_make_asset_card(entry))
	return box


func _make_asset_card(entry: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	panel.tooltip_text = _describe_entry(entry)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	row.add_child(_make_preview(entry))

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)

	var id_label := Label.new()
	id_label.text = _entry_id(entry)
	id_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	id_label.tooltip_text = id_label.text
	text_box.add_child(id_label)

	var status_label := Label.new()
	var status := str(entry.get("status", "unknown"))
	status_label.text = "%s | %s" % [status, str(entry.get("type", ""))]
	status_label.add_theme_color_override("font_color", STATUS_COLORS.get(status, Color.WHITE))
	text_box.add_child(status_label)

	var size_label := Label.new()
	size_label.text = "size: %s | anchor: %s" % [str(entry.get("size", entry.get("required_size", entry.get("source_size", [])))), str(entry.get("anchor", "unset"))]
	size_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(size_label)

	var path_label := Label.new()
	path_label.text = _preview_path(entry)
	path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	path_label.tooltip_text = path_label.text
	text_box.add_child(path_label)

	return panel


func _make_preview(entry: Dictionary) -> Control:
	var holder := PanelContainer.new()
	holder.custom_minimum_size = PREVIEW_SIZE

	var path := _preview_path(entry)
	if path.is_empty() or not ResourceLoader.exists(path):
		var label := Label.new()
		label.text = "missing"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		holder.add_child(label)
		return holder

	var resource := ResourceLoader.load(path)
	var texture := _texture_from_resource(resource)
	if texture == null:
		var label := Label.new()
		label.text = resource.get_class() if resource != null else "unloadable"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		holder.add_child(label)
		return holder

	var rect := TextureRect.new()
	rect.custom_minimum_size = PREVIEW_SIZE
	rect.texture = texture
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	holder.add_child(rect)
	return holder


func _texture_from_resource(resource: Resource) -> Texture2D:
	if resource is Texture2D:
		return resource as Texture2D
	if resource is SpriteFrames:
		var frames := resource as SpriteFrames
		for animation_name in frames.get_animation_names():
			if frames.get_frame_count(animation_name) > 0:
				return frames.get_frame_texture(animation_name, 0)
	return null


func _entry_id(entry: Dictionary) -> String:
	if entry.has("id"):
		return str(entry["id"])
	for key in entry.keys():
		if str(key).begins_with("_"):
			continue
	return str(entry.get("type", "asset"))


func _preview_path(entry: Dictionary) -> String:
	for key in ["path", "current_texture", "spriteframes", "sheet", "atlas", "available_path"]:
		if entry.has(key):
			return str(entry[key])
	if entry.has("paths") and entry["paths"] is Array and not entry["paths"].is_empty():
		return str(entry["paths"][0])
	return ""


func _describe_entry(entry: Dictionary) -> String:
	return "%s\nstatus: %s\nusage: %s\ncollision: %s" % [
		_entry_id(entry),
		str(entry.get("status", "")),
		str(entry.get("usage", [])),
		str(entry.get("collision", "unset")),
	]
