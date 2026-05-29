extends Node


func _ready() -> void:
	ConfigLoader.load_all()
	var path := ConfigLoader.get_asset_path("asset_preview_scene")
	_assert_equal(path, "res://scenes/debug/asset_preview_scene.tscn", "资源预览场景应登记在资源注册表")
	_assert_true(ResourceLoader.exists(path), "资源预览场景文件应存在")

	var packed := load(path) as PackedScene
	_assert_true(packed != null, "资源预览场景应能加载为 PackedScene")
	var instance := packed.instantiate()
	add_child(instance)
	await get_tree().process_frame

	_assert_true(instance.find_children("", "ScrollContainer", true, false).size() > 0, "资源预览场景应包含滚动预览区")
	_assert_true(instance.find_children("", "TextureRect", true, false).size() > 0, "资源预览场景应显示至少一个纹理预览")
	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
