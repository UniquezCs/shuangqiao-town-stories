extends Node

const DiagnosticsCapture := preload("res://addons/godot_ai/utils/diagnostics_capture.gd")
const EditorLogBuffer := preload("res://addons/godot_ai/utils/editor_log_buffer.gd")
const ScriptHandler := preload("res://addons/godot_ai/handlers/script_handler.gd")

const TEMP_VALID_SCRIPT := "res://tests/.tmp_godot_ai_valid_script.gd"
const TEMP_INVALID_SCRIPT := "res://tests/.tmp_godot_ai_invalid_script.gd"


func _ready() -> void:
	_assert_capture_uses_top_level_source_location()
	_assert_capture_filters_to_target_file()
	_assert_editor_log_cursor_reports_truncation()
	_assert_create_script_returns_empty_diagnostics_for_valid_source()
	_assert_fallback_diagnostic_points_to_last_non_empty_line()
	_cleanup_temp_files()
	get_tree().quit()


func _assert_capture_uses_top_level_source_location() -> void:
	var buffer := EditorLogBuffer.new()
	var result: Dictionary = DiagnosticsCapture.capture_this_file(buffer, "res://target.gd", func() -> Dictionary:
		buffer.append("error", "bad target", "res://target.gd", 7, "_ready")
		return {"ran": true}
	)
	var diagnostics: Array = result.get("diagnostics", [])

	_assert_equal(diagnostics.size(), 1, "诊断捕获应识别顶层 path/line/function")
	_assert_equal(diagnostics[0].get("path"), "res://target.gd", "诊断 path 应来自日志源路径")
	_assert_equal(diagnostics[0].get("line"), 7, "诊断 line 应来自日志源行号")
	_assert_equal(diagnostics[0].get("function"), "_ready", "诊断 function 应来自日志源函数")
	_assert_equal(result.get("diagnostics_detail"), "log_capture", "命中日志时应标记 log_capture")


func _assert_capture_filters_to_target_file() -> void:
	var buffer := EditorLogBuffer.new()
	var result: Dictionary = DiagnosticsCapture.capture_this_file(buffer, "res://target.gd", func() -> Dictionary:
		buffer.append("error", "other file", "res://other.gd", 2, "_ready")
		buffer.append("error", "target file", "res://target.gd", 4, "_ready")
		return {}
	)
	var diagnostics: Array = result.get("diagnostics", [])

	_assert_equal(diagnostics.size(), 1, "诊断捕获应只保留目标文件")
	_assert_equal(diagnostics[0].get("text"), "target file", "目标文件诊断应被保留")


func _assert_editor_log_cursor_reports_truncation() -> void:
	var buffer := EditorLogBuffer.new()
	for i in range(EditorLogBuffer.MAX_LINES + 5):
		buffer.append("error", "entry-%d" % i, "res://target.gd", i + 1, "_ready")

	var captured: Dictionary = buffer.get_since(0)
	var entries: Array = captured.get("entries", [])

	_assert_true(captured.get("truncated", false), "过旧 cursor 应标记 truncated")
	_assert_equal(entries.size(), EditorLogBuffer.MAX_LINES, "溢出后应只返回保留窗口内日志")
	_assert_equal(entries[0].get("text"), "entry-5", "溢出后第一条应是最早保留日志")
	_assert_equal(captured.get("next_cursor"), EditorLogBuffer.MAX_LINES + 5, "next_cursor 应推进到最新追加位置")


func _assert_create_script_returns_empty_diagnostics_for_valid_source() -> void:
	_cleanup_temp_files()
	var handler := ScriptHandler.new(null)
	var response: Dictionary = handler.create_script({
		"path": TEMP_VALID_SCRIPT,
		"content": "extends Node\n\nfunc answer() -> int:\n\treturn 42\n",
	})
	var data: Dictionary = response.get("data", {})

	_assert_equal(data.get("diagnostics_status"), "checked", "合法脚本应完成诊断检查")
	_assert_equal(data.get("diagnostics_detail"), "none", "合法脚本不应产生诊断详情")
	_assert_equal((data.get("diagnostics", []) as Array).size(), 0, "合法脚本不应产生诊断")


func _assert_fallback_diagnostic_points_to_last_non_empty_line() -> void:
	var diagnostic: Dictionary = ScriptHandler._fallback_gdscript_diagnostic(
		TEMP_INVALID_SCRIPT,
		FAILED,
		"extends Node\n\nfunc broken() -> void:\n\tvar value = \n\n",
	)

	_assert_equal(diagnostic.get("path"), TEMP_INVALID_SCRIPT, "fallback 诊断应指向目标脚本")
	_assert_equal(diagnostic.get("line"), 4, "fallback 行号应指向最后一行非空源码")
	_assert_equal(diagnostic.get("details", {}).get("code"), "gdscript_reload_failed", "fallback 诊断应携带稳定 code")


func _cleanup_temp_files() -> void:
	for path in [TEMP_VALID_SCRIPT, TEMP_INVALID_SCRIPT, TEMP_VALID_SCRIPT + ".uid", TEMP_INVALID_SCRIPT + ".uid"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_cleanup_temp_files()
		push_error(message)
		get_tree().quit(1)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_cleanup_temp_files()
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)
