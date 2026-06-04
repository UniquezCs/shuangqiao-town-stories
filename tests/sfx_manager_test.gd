extends Node

const SfxManagerScript := preload("res://scripts/autoload/sfx_manager.gd")


func _ready() -> void:
	var stream := load(SfxManagerScript.CASH_RECEIVED_PATH)
	_assert_true(stream != null, "收钱音效资源应能加载")
	_assert_true(stream.has_method("get_length"), "收钱音效应是可测量长度的音频流")
	_assert_true(absf(stream.get_length() - 0.5) <= 0.08, "收钱音效长度应约为 0.5 秒")

	var manager := SfxManagerScript.new()
	manager.name = "TestSfxManager"
	add_child(manager)
	await get_tree().process_frame

	_assert_true(manager.sfx_player != null, "SfxManager 应创建 SFX 播放器")
	var expected_bus := "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	_assert_equal(manager.sfx_player.bus, expected_bus, "SFX 播放器应使用项目可用的音效总线")

	SignalBus.sale_completed.emit("apple", 3, 2)
	await get_tree().process_frame

	_assert_true(manager.sfx_player.stream != null, "成交后应绑定收钱音效")
	_assert_equal(manager.sfx_player.stream.resource_path, SfxManagerScript.CASH_RECEIVED_PATH, "成交后应播放收钱音效资源")

	manager.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
