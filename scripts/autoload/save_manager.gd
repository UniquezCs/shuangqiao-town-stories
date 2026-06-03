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
	}
	var json := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("自动存档失败：%s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(json)
	file.close()
	return true


func load_autosave() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("读取存档失败：%s" % error_string(FileAccess.get_open_error()))
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("存档不是有效 JSON Dictionary")
		return {}
	return _migrate(parsed as Dictionary)


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
		push_warning("存档版本较新，尝试按当前版本读取：%d" % version)
	return data
