extends Node

const ApiHandler := preload("res://addons/godot_ai/handlers/api_handler.gd")


func _ready() -> void:
	_assert_class_info_is_paged_and_json_safe()
	_assert_unknown_class_returns_suggestions()
	_assert_invalid_sections_return_suggestions()
	get_tree().quit()


func _assert_class_info_is_paged_and_json_safe() -> void:
	var handler := ApiHandler.new()
	var response := handler.get_class_info({
		"class_name": "Node2D",
		"sections": ["properties", "methods", "signals", "enums", "constants", "inheritors"],
		"include_inheritors": true,
		"limit": 5,
	})

	_assert_true(response.has("data"), "get_class_info 应返回 data")
	var data: Dictionary = response["data"]
	_assert_equal(data.get("class_name"), "Node2D", "class_name 应回显查询类名")
	_assert_true(data.get("method_count", 0) >= data.get("method_returned_count", 0), "method_count 应覆盖分页返回数")
	_assert_true(data.get("method_returned_count", 0) <= 5, "limit 应限制 methods 返回数量")
	_assert_true(data.has("concrete_inheritors"), "include_inheritors 应返回可实例化子类")

	var json_text := JSON.stringify(response)
	var parser := JSON.new()
	_assert_equal(parser.parse(json_text), OK, "get_class_info 返回值必须可 JSON 编码")


func _assert_unknown_class_returns_suggestions() -> void:
	var handler := ApiHandler.new()
	var response := handler.get_class_info({"class_name": "Node2DD"})

	_assert_true(response.has("error"), "未知类名应返回 error")
	var suggestions: Array = response["error"].get("data", {}).get("suggestions", [])
	_assert_true(suggestions.has("Node2D"), "未知类名应给出 Node2D 模糊建议")


func _assert_invalid_sections_return_suggestions() -> void:
	var handler := ApiHandler.new()
	var response := handler.get_class_info({
		"class_name": "Node2D",
		"sections": ["methds"],
	})

	_assert_true(response.has("error"), "未知 section 应返回 error")
	var suggestions: Dictionary = response["error"].get("data", {}).get("suggestions", {})
	_assert_true(suggestions.has("methds"), "未知 section 应返回对应建议")
	_assert_true((suggestions["methds"] as Array).has("methods"), "methds 应建议 methods")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)
