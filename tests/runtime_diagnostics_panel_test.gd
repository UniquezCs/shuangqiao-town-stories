extends Node


func _ready() -> void:
	ConfigLoader.load_all()
	var path := ConfigLoader.get_asset_path("runtime_diagnostics_panel")
	_assert_equal(path, "res://scenes/debug/runtime_diagnostics_panel.tscn", "运行诊断面板应登记在资源注册表")
	_assert_true(ResourceLoader.exists(path), "运行诊断面板场景文件应存在")

	RuntimeDiagnostics.clear()
	RuntimeDiagnostics.report_issue(
		"config",
		"load_failed",
		"配置文件 JSON 解析失败",
		{"path": "res://configs/items.json"},
		RuntimeDiagnostics.SEVERITY_ERROR
	)

	var packed := load(path) as PackedScene
	_assert_true(packed != null, "运行诊断面板应能加载为 PackedScene")
	var instance := packed.instantiate()
	add_child(instance)
	await get_tree().process_frame

	var labels := instance.find_children("", "Label", true, false)
	var text := ""
	for label in labels:
		text += (label as Label).text + "\n"
	_assert_true(text.contains("Runtime Diagnostics"), "运行诊断面板应显示标题")
	_assert_true(text.contains("total: 1"), "运行诊断面板应显示问题总数")
	_assert_true(text.contains("config"), "运行诊断面板应显示问题来源")
	_assert_true(text.contains("load_failed"), "运行诊断面板应显示问题代码")
	_assert_true(text.contains("配置文件 JSON 解析失败"), "运行诊断面板应显示问题消息")
	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
