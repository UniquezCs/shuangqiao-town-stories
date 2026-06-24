extends Node


func _ready() -> void:
	RuntimeDiagnostics.clear()
	RuntimeDiagnostics.report_issue(
		"config",
		"load_failed",
		"配置文件 JSON 解析失败",
		{"path": "res://configs/items.json"},
		RuntimeDiagnostics.SEVERITY_WARNING
	)

	var issues := RuntimeDiagnostics.get_issues()
	_assert_equal(issues.size(), 1, "诊断入口应记录一条问题")
	_assert_equal(str(issues[0].get("source", "")), "config", "诊断问题应记录来源")
	_assert_equal(str(issues[0].get("code", "")), "load_failed", "诊断问题应记录代码")
	_assert_equal(str(issues[0].get("severity", "")), RuntimeDiagnostics.SEVERITY_WARNING, "诊断问题应记录级别")
	_assert_equal(str(issues[0].get("data", {}).get("path", "")), "res://configs/items.json", "诊断问题应保留结构化数据")

	var summary := RuntimeDiagnostics.get_summary()
	_assert_equal(int(summary.get("total", 0)), 1, "诊断摘要应暴露总数")
	_assert_equal(int(summary.get("by_source", {}).get("config", 0)), 1, "诊断摘要应按来源统计")
	_assert_equal(int(summary.get("by_severity", {}).get(RuntimeDiagnostics.SEVERITY_WARNING, 0)), 1, "诊断摘要应按级别统计")

	var display_rows := RuntimeDiagnostics.get_display_rows()
	_assert_equal(display_rows.size(), 1, "诊断入口应为可见面板提供精简问题行")
	_assert_equal(str(display_rows[0].get("source", "")), "config", "精简问题行应包含来源")
	_assert_equal(str(display_rows[0].get("code", "")), "load_failed", "精简问题行应包含代码")
	_assert_equal(str(display_rows[0].get("message", "")), "配置文件 JSON 解析失败", "精简问题行应包含消息")

	var log_path := "user://runtime_diagnostics_test.json"
	_assert_true(RuntimeDiagnostics.write_log(log_path), "诊断入口应能把摘要与问题落盘")
	var log_file := FileAccess.open(log_path, FileAccess.READ)
	_assert_true(log_file != null, "诊断日志文件应能被读回")
	var parsed: Variant = JSON.parse_string(log_file.get_as_text())
	_assert_true(parsed is Dictionary, "诊断日志应是 JSON 字典")
	_assert_equal(int(parsed.get("summary", {}).get("total", 0)), 1, "诊断日志应包含摘要")
	_assert_equal((parsed.get("issues", []) as Array).size(), 1, "诊断日志应包含问题列表")

	var auto_log_path := "user://runtime_diagnostics_auto_test.json"
	ProjectSettings.set_setting(RuntimeDiagnostics.AUTO_EXPORT_ON_ERROR_SETTING, true)
	ProjectSettings.set_setting(RuntimeDiagnostics.AUTO_EXPORT_PATH_SETTING, auto_log_path)
	RuntimeDiagnostics.report_issue("save", "read_failed", "存档读取失败", {}, RuntimeDiagnostics.SEVERITY_ERROR)
	var auto_log_file := FileAccess.open(auto_log_path, FileAccess.READ)
	_assert_true(auto_log_file != null, "错误级诊断应在开关打开时自动导出日志")
	var auto_parsed: Variant = JSON.parse_string(auto_log_file.get_as_text())
	_assert_true(auto_parsed is Dictionary, "自动导出的诊断日志应是 JSON 字典")
	_assert_equal(int(auto_parsed.get("summary", {}).get("by_severity", {}).get(RuntimeDiagnostics.SEVERITY_ERROR, 0)), 1, "自动导出日志应包含错误级统计")
	ProjectSettings.set_setting(RuntimeDiagnostics.AUTO_EXPORT_ON_ERROR_SETTING, false)
	ProjectSettings.set_setting(RuntimeDiagnostics.AUTO_EXPORT_PATH_SETTING, "user://runtime_diagnostics.json")

	RuntimeDiagnostics.clear("config")
	_assert_equal(RuntimeDiagnostics.get_issues("config").size(), 0, "诊断入口应支持按来源清理")
	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
