extends Node

const MainScript := preload("res://scripts/main.gd")


func _ready() -> void:
	GameState.reset_game()
	var main := Node2D.new()
	main.set_script(MainScript)
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_5
	_assert_equal(main.call("_hotbar_index_from_event", key_event), 4, "数字键 5 应选择第 5 个快捷栏格")
	key_event.keycode = KEY_KP_9
	_assert_equal(main.call("_hotbar_index_from_event", key_event), 8, "小键盘 9 应选择第 9 个快捷栏格")
	main.free()

	_assert_equal(Hotbar.slot_count, 9, "快捷栏应固定为 9 格")
	_assert_equal(str(Hotbar.slots[0].get("item_id", "")), PrototypeConstants.ITEM_WATERING_CAN, "第 1 格初始应是水壶")
	_assert_equal(str(Hotbar.slots[1].get("item_id", "")), PrototypeConstants.ITEM_HOE, "第 2 格初始应是锄头")
	_assert_equal(str(Hotbar.slots[2].get("item_id", "")), PrototypeConstants.ITEM_SICKLE, "第 3 格初始应是镰刀")
	_assert_equal(Hotbar.selected_index, 0, "新游戏应默认选中第 1 格")
	_assert_equal(GameState.current_tool, PrototypeConstants.TOOL_WATER, "选中水壶格时当前工具应为水壶")

	Hotbar.select_slot(1)
	_assert_equal(GameState.current_tool, PrototypeConstants.TOOL_HOE, "按 2 选中锄头格后当前工具应为锄头")
	Hotbar.select_slot(3)
	_assert_equal(GameState.current_tool, "", "选中空快捷格时当前手上应没有东西")

	Inventory.insert_to_slot(3, PrototypeConstants.ITEM_APPLE_SEED, 4)
	_assert_true(Hotbar.transfer_inventory_to_hotbar(3, 4), "背包种子应能拖到快捷栏")
	_assert_true(Inventory.slots[3].is_empty(), "拖到快捷栏后原背包格应清空")
	_assert_equal(str(Hotbar.slots[4].get("item_id", "")), PrototypeConstants.ITEM_APPLE_SEED, "快捷栏应收到背包种子")
	_assert_equal(int(Hotbar.slots[4].get("count", 0)), 4, "快捷栏应保留物品数量")
	Hotbar.select_slot(4)
	_assert_equal(GameState.current_tool, PrototypeConstants.TOOL_SEED, "选中种子格时当前工具应为播种")

	_assert_true(Hotbar.transfer_hotbar_to_inventory(4, 3), "快捷栏物品应能拖回背包")
	_assert_true(Hotbar.slots[4].is_empty(), "拖回背包后快捷栏格应清空")
	_assert_equal(str(Inventory.slots[3].get("item_id", "")), PrototypeConstants.ITEM_APPLE_SEED, "背包应收到快捷栏物品")

	Hotbar.select_slot(0)
	_assert_true(Hotbar.move_slot(0, 8), "快捷栏内部应能拖拽换位")
	_assert_equal(Hotbar.selected_index, 8, "拖动当前选中物品时选中框应跟随物品")
	_assert_equal(GameState.current_tool, PrototypeConstants.TOOL_WATER, "拖动当前选中物品后当前工具应保持为该物品对应工具")

	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
