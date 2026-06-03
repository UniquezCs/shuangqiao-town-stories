extends Node


func _ready() -> void:
	var stream := load(MusicManager.DEFAULT_BGM_PATH)
	_assert_true(stream != null, "默认 BGM 资源应能加载")

	MusicManager.stop_bgm()
	MusicManager.play_default_bgm()
	await get_tree().process_frame

	_assert_true(MusicManager.bgm_player != null, "MusicManager 应创建 BGM 播放器")
	_assert_true(MusicManager.bgm_player.stream != null, "BGM 播放器应绑定音频流")
	_assert_equal(MusicManager.bgm_player.stream.resource_path, MusicManager.DEFAULT_BGM_PATH, "BGM 播放器应使用默认 BGM")
	if DisplayServer.get_name() != "headless":
		_assert_true(MusicManager.is_playing(), "默认 BGM 应进入播放状态")
	_assert_equal(int(MusicManager.bgm_player.stream.get("loop_mode")), 1, "默认 BGM 应设置为循环播放")

	MusicManager.stop_bgm()
	stream = null
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
