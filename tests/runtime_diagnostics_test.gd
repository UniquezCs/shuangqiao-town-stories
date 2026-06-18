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

	RuntimeDiagnostics.clear("config")
	_assert_equal(RuntimeDiagnostics.get_issues().size(), 0, "诊断入口应支持按来源清理")
	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)
