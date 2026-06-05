extends Node

const TITLE_SCENE := preload("res://scenes/title_screen.tscn")

func _ready() -> void:
	SaveManager.SAVE_PATH = "user://test_title_autosave.json"
	SaveManager.delete_autosave()

	var title := TITLE_SCENE.instantiate()
	add_child(title)
	await get_tree().process_frame

	_assert_equal(title.get("title_text"), "双桥镇往事", "标题界面应显示暂定游戏名")
	_assert_equal(title.get_node("UI/Menu/LoadButton").disabled, true, "无存档时读取存档按钮应置灰")
	_assert_true(ResourceLoader.exists("res://assets/generated/sprites/ui/title/title_background_1920x1080.png"), "标题界面背景图应存在")
	_assert_true(ResourceLoader.exists("res://assets/generated/sprites/ui/intro/story_01_factory_layoff_1920x1080.png"), "开场漫画第 1 张应存在")
	_assert_true(ResourceLoader.exists("res://assets/generated/sprites/ui/intro/story_02_family_pressure_1920x1080.png"), "开场漫画第 2 张应存在")
	_assert_true(ResourceLoader.exists("res://assets/generated/sprites/ui/intro/story_03_hometown_stall_1920x1080.png"), "开场漫画第 3 张应存在")

	GameState.cash = 9
	_assert_true(SaveManager.save_autosave(), "测试应能准备一个存档")
	title.call("refresh_save_state")
	_assert_equal(title.get_node("UI/Menu/LoadButton").disabled, false, "有存档时读取存档按钮应可用")
	title.call("_on_new_game_pressed")
	_assert_equal(title.get_node("UI/ConfirmNewGameDialog").visible, true, "已有存档时新游戏应二次确认")
	title.call("_start_new_game")
	await get_tree().process_frame
	_assert_true(title.get_node_or_null("IntroLayer") != null, "确认新游戏后应先显示三幕开场漫画")
	_assert_equal(title.get_node("UI").visible, false, "播放开场漫画时标题菜单应隐藏")

	SaveManager.delete_autosave()
	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
