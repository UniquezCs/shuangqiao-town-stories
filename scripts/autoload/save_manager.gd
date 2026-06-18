extends Node

const SCHEMA_VERSION := 1

var SAVE_PATH := "user://autosave.json"
var _pending_load: Dictionary = {}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_autosave() -> bool:
	var save_data := {
		"schema_version": SCHEMA_VERSION,
		"game_state": GameState.to_save_data(),
		"inventory": Inventory.to_save_data(),
		"hotbar": Hotbar.to_save_data(),
	}
	var json := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_report_save_issue(
			"write_failed",
			"自动存档失败：%s" % error_string(FileAccess.get_open_error()),
			{"path": SAVE_PATH}
		)
		return false
	file.store_string(json)
	file.close()
	return true


func load_autosave() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_report_save_issue(
			"read_failed",
			"读取存档失败：%s" % error_string(FileAccess.get_open_error()),
			{"path": SAVE_PATH}
		)
		return {}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var error := parser.parse(text)
	if error != OK:
		_report_save_issue(
			"invalid_json",
			"存档 JSON 解析失败：%s" % parser.get_error_message(),
			{"path": SAVE_PATH}
		)
		return {}
	if typeof(parser.data) != TYPE_DICTIONARY:
		_report_save_issue(
			"invalid_json",
			"存档不是有效 JSON Dictionary",
			{"path": SAVE_PATH}
		)
		return {}
	return _migrate(parser.data as Dictionary)


func delete_autosave() -> void:
	if not has_save():
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func set_pending_load(data: Dictionary) -> void:
	_pending_load = data.duplicate(true)


func consume_pending_load() -> Dictionary:
	var data := _pending_load.duplicate(true)
	_pending_load = {}
	return data


func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("schema_version", 0))
	if version <= 0:
		data["schema_version"] = SCHEMA_VERSION
	elif version > SCHEMA_VERSION:
		_report_save_issue(
			"future_schema",
			"存档版本较新，尝试按当前版本读取：%d" % version,
			{"path": SAVE_PATH, "schema_version": version}
		)
	return data


func _report_save_issue(code: String, message: String, data: Dictionary = {}) -> void:
	RuntimeDiagnostics.report_issue("save", code, message, data, RuntimeDiagnostics.SEVERITY_WARNING)
	push_warning(message)
