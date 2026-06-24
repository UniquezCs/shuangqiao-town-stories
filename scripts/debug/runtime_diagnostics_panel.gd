extends Control

const EMPTY_TEXT := "No runtime diagnostics reported."

var _summary_label: Label
var _issues_box: VBoxContainer
var _status_label: Label


func _ready() -> void:
	_build_ui()
	RuntimeDiagnostics.issue_reported.connect(_on_issue_reported)
	_refresh()


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
	title.text = "Runtime Diagnostics"
	title.add_theme_font_size_override("font_size", 28)
	layout.add_child(title)

	_summary_label = Label.new()
	layout.add_child(_summary_label)

	var export_button := Button.new()
	export_button.text = "Export Log"
	export_button.pressed.connect(_on_export_pressed)
	layout.add_child(export_button)

	_status_label = Label.new()
	layout.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	_issues_box = VBoxContainer.new()
	_issues_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_issues_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_issues_box)


func _refresh() -> void:
	var summary := RuntimeDiagnostics.get_summary()
	_summary_label.text = "total: %d | warnings: %d | errors: %d" % [
		int(summary.get("total", 0)),
		int(summary.get("by_severity", {}).get(RuntimeDiagnostics.SEVERITY_WARNING, 0)),
		int(summary.get("by_severity", {}).get(RuntimeDiagnostics.SEVERITY_ERROR, 0)),
	]

	for child in _issues_box.get_children():
		child.queue_free()

	var rows := RuntimeDiagnostics.get_display_rows()
	if rows.is_empty():
		var empty_label := Label.new()
		empty_label.text = EMPTY_TEXT
		_issues_box.add_child(empty_label)
		return

	for row in rows:
		_issues_box.add_child(_make_issue_label(row))


func _make_issue_label(row: Dictionary) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "[%s] %s:%s - %s" % [
		str(row.get("severity", "")),
		str(row.get("source", "")),
		str(row.get("code", "")),
		str(row.get("message", "")),
	]
	return label


func _on_issue_reported(_issue: Dictionary) -> void:
	_refresh()


func _on_export_pressed() -> void:
	var path := str(ProjectSettings.get_setting(RuntimeDiagnostics.AUTO_EXPORT_PATH_SETTING, "user://runtime_diagnostics.json"))
	_status_label.text = "exported: %s" % path if RuntimeDiagnostics.write_log(path) else "export failed: %s" % path
