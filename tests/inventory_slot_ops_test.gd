extends Node


func _ready() -> void:
	GameState.reset_game()
	Inventory.configure_slot_count(4)
	Inventory.set_count(PrototypeConstants.ITEM_APPLE_SEED, 0)

	_assert_equal(Inventory.slots.size(), 4, "背包 slots 应始终保持固定格数")
	_assert_true(Inventory.get_slots_with_empty()[0].is_empty(), "空背包格应以空字典保留")

	_assert_true(Inventory.insert_to_slot(0, PrototypeConstants.ITEM_APPLE, 18), "应能插入苹果到指定空格")
	_assert_true(Inventory.insert_to_slot(1, PrototypeConstants.ITEM_APPLE, 5), "应能插入第二组苹果")
	_assert_true(Inventory.move_slot(1, 0), "同类物品拖拽到已有堆叠应合并")
	_assert_equal(int(Inventory.slots[0].get("count", 0)), 20, "合并后目标格不应超过 stack_size")
	_assert_equal(int(Inventory.slots[1].get("count", 0)), 3, "超过 stack_size 的剩余数量应留在来源格")

	_assert_true(Inventory.insert_to_slot(2, "cabbage", 2), "应能插入不同商品")
	_assert_true(Inventory.move_slot(0, 2), "不同商品拖拽应交换格子")
	_assert_equal(str(Inventory.slots[0].get("item_id", "")), "cabbage", "交换后来源格应变为目标格商品")
	_assert_equal(str(Inventory.slots[2].get("item_id", "")), PrototypeConstants.ITEM_APPLE, "交换后目标格应变为来源格商品")

	var removed: Dictionary = Inventory.remove_from_slot(2, 4)
	_assert_equal(str(removed.get("item_id", "")), PrototypeConstants.ITEM_APPLE, "指定格移除应返回物品 ID")
	_assert_equal(int(removed.get("count", 0)), 4, "指定格移除应返回实际移除数量")
	_assert_equal(int(Inventory.slots[2].get("count", 0)), 16, "指定格移除后剩余数量应正确")
	_assert_equal(Inventory.get_count(PrototypeConstants.ITEM_APPLE), 19, "总苹果数应保持正确")

	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
