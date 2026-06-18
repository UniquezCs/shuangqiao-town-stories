extends Node

const TEMP_VALID_CONFIG := "res://tests/.tmp_config_loader_valid.json"
const TEMP_INVALID_CONFIG := "res://tests/.tmp_config_loader_invalid.json"
const TEMP_ARRAY_CONFIG := "res://tests/.tmp_config_loader_array.json"
const TEMP_MISSING_CONFIG := "res://tests/.tmp_config_loader_missing.json"


func _ready() -> void:
	RuntimeDiagnostics.clear()
	var fallback := {"apple": {"name": "苹果", "stack_size": 20}}
	var loader := preload("res://scripts/autoload/config_loader.gd").new()
	add_child(loader)

	_write_text(TEMP_VALID_CONFIG, "{\"pear\":{\"name\":\"梨\",\"stack_size\":20}}")
	_write_text(TEMP_INVALID_CONFIG, "{\"pear\":")
	_write_text(TEMP_ARRAY_CONFIG, "[\"pear\"]")
	if FileAccess.file_exists(TEMP_MISSING_CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MISSING_CONFIG))

	_assert_equal(loader.call("_load_json", TEMP_VALID_CONFIG, fallback), {"pear": {"name": "梨", "stack_size": 20.0}}, "合法配置应覆盖 fallback")
	_assert_equal(loader.call("_load_json", TEMP_INVALID_CONFIG, fallback), fallback, "JSON 解析失败时应保留 fallback")
	_assert_equal(loader.call("_load_json", TEMP_ARRAY_CONFIG, fallback), fallback, "顶层不是 Dictionary 时应保留 fallback")
	_assert_equal(loader.call("_load_json", TEMP_MISSING_CONFIG, fallback), fallback, "配置文件缺失时应保留 fallback")
	_assert_equal(RuntimeDiagnostics.get_issues("config").size(), 3, "配置加载失败应进入统一诊断入口")

	_cleanup()
	loader.queue_free()
	get_tree().quit()


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_assert_true(file != null, "应能写入临时配置：%s" % path)
	file.store_string(text)
	file.close()


func _cleanup() -> void:
	for path in [TEMP_VALID_CONFIG, TEMP_INVALID_CONFIG, TEMP_ARRAY_CONFIG, TEMP_MISSING_CONFIG]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_cleanup()
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_cleanup()
		push_error(message)
		get_tree().quit(1)
