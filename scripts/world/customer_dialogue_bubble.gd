extends Node2D

const DISPLAY_SECONDS := 2.4

var _panel: PanelContainer
var _label: Label
var _tween: Tween = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	if _label != null:
		return
	z_index = 30
	_panel = PanelContainer.new()
	_panel.position = Vector2(-72, -24)
	_panel.custom_minimum_size = Vector2(144, 0)
	add_child(_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.96, 0.78, 0.94)
	style.border_color = Color(0.25, 0.18, 0.1, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	_panel.add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.name = "Text"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04, 1.0))
	_label.add_theme_font_size_override("font_size", 13)
	_panel.add_child(_label)
	visible = false


func show_line(text: String) -> void:
	if _label == null:
		_build_ui()
	_label.text = text
	visible = true
	modulate.a = 0.0
	position = Vector2(0, -92)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position:y", -100.0, 0.18)
	_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.18)
	_tween.tween_interval(DISPLAY_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, 0.45)
	_tween.tween_callback(func() -> void:
		visible = false
	)


func get_text() -> String:
	return "" if _label == null else _label.text
