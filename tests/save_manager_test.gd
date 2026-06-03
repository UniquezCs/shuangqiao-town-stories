extends Node

const SaveManagerScript := preload("res://scripts/autoload/save_manager.gd")


func _ready() -> void:
	var save_manager := Node.new()
	save_manager.set_script(SaveManagerScript)
	add_child(save_manager)
	save_manager.set("SAVE_PATH", "user://test_autosave.json")
	save_manager.call("delete_autosave")

	GameState.reset_game()
	GameState.cash = 42
	GameState.day_index = 3
	GameState.backpack_level = 2
	GameState.stall_level = 2
	GameState.current_game_minute = 8 * 60 + 15
	GameState.seed_shop_apple_price = 4
	GameState.seed_shop_apple_stock = 7
	GameState.set_farm_plot_data("field_1_1", {
		"state": "ready",
		"crop_id": PrototypeConstants.ITEM_APPLE,
		"days_grown": 0,
	})
	Inventory.configure_slot_count(12)
	Inventory.set_count(PrototypeConstants.ITEM_APPLE, 6)
	Inventory.set_count(PrototypeConstants.ITEM_PEAR, 2)

	_assert_true(save_manager.call("save_autosave"), "SaveManager 应能写入 autosave")
	_assert_true(save_manager.call("has_save"), "写入后应检测到本地存档")

	GameState.reset_game()
	_assert_equal(GameState.cash, 0, "测试重置应清空现金")
	var loaded: Dictionary = save_manager.call("load_autosave")
	_assert_true(not loaded.is_empty(), "SaveManager 应能读取 autosave JSON")
	GameState.apply_save_data(loaded.get("game_state", {}))
	Inventory.apply_save_data(loaded.get("inventory", {}))

	_assert_equal(GameState.cash, 42, "读档应恢复现金")
	_assert_equal(GameState.day_index, 3, "读档应恢复天数")
	_assert_equal(GameState.backpack_level, 2, "读档应恢复背包等级")
	_assert_equal(GameState.stall_level, 2, "读档应恢复摊位等级")
	_assert_equal(GameState.current_game_minute, 8 * 60 + 15, "读档应恢复游戏时间")
	_assert_equal(GameState.seed_shop_apple_price, 4, "读档应恢复今日苹果进价")
	_assert_equal(GameState.seed_shop_apple_stock, 7, "读档应恢复今日苹果库存")
	_assert_equal(GameState.get_farm_plot_state("field_1_1"), "ready", "读档应恢复农田状态")
	_assert_equal(Inventory.slot_count, 12, "读档应恢复背包格数")
	_assert_equal(Inventory.get_count(PrototypeConstants.ITEM_APPLE), 6, "读档应恢复苹果数量")
	_assert_equal(Inventory.get_count(PrototypeConstants.ITEM_PEAR), 2, "读档应恢复梨数量")

	save_manager.call("delete_autosave")
	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
