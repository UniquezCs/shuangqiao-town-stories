extends Node

const StallScript := preload("res://scripts/world/stall.gd")


func _ready() -> void:
	GameState.reset_game()
	GameState.cash = 200
	_assert_equal(GameState.get_stall_slot_count(), 4, "1 级摊位应有 4 个商品格")
	_assert_true(GameState.upgrade_stall(), "现金足够时应能升级摊位")
	_assert_equal(GameState.get_stall_slot_count(), 6, "2 级摊位应有 6 个商品格")

	var setup_script: Script = load("res://scripts/ui/stall_setup_panel.gd")
	_assert_true(setup_script != null, "应新增 StallSetupPanel 脚本")
	if setup_script == null:
		return
	var setup_panel := CanvasLayer.new()
	setup_panel.set_script(setup_script)
	add_child(setup_panel)
	await get_tree().process_frame

	Inventory.set_count(PrototypeConstants.ITEM_APPLE, 12)
	setup_panel.call("open_for_stall", null)
	var large_apple_slot_index := _slot_index_for(PrototypeConstants.ITEM_APPLE)
	setup_panel.call("handle_slot_drop", {
		"source": "backpack",
		"slot_index": large_apple_slot_index,
		"slot": Inventory.slots[large_apple_slot_index].duplicate(),
	}, "stall", 0)
	_assert_equal(int(setup_panel.get("_amount_spin").get("max_value")), 12, "摆摊准备不应再被摊位总上架数量限制")
	setup_panel.get("_amount_spin").set("value", 12)
	setup_panel.call("_confirm_transfer")
	_assert_equal(int(((setup_panel.get("_stall_slots") as Array)[0] as Dictionary).get("count", 0)), 12, "摊位草稿应允许超过旧总上限的商品数量")
	setup_panel.call("cancel_setup")

	Inventory.set_count(PrototypeConstants.ITEM_APPLE, 5)
	setup_panel.call("open_for_stall", null)
	_assert_true(not get_tree().paused, "打开摆摊准备面板时不应暂停游戏")
	_assert_equal((setup_panel.get("_stall_slots") as Array).size(), GameState.get_stall_slot_count(), "摆摊准备草稿格数应来自摊位等级")
	var apple_slot_index := _slot_index_for(PrototypeConstants.ITEM_APPLE)
	_assert_true(apple_slot_index >= 0, "测试应找到背包苹果格")
	setup_panel.call("handle_slot_drop", {
		"source": "backpack",
		"slot_index": apple_slot_index,
		"slot": Inventory.slots[apple_slot_index].duplicate(),
	}, "stall", 0)
	_assert_true(bool(setup_panel.get("_dialog").get("visible")), "背包拖到摊位格时应打开数量和定价确认")
	setup_panel.get("_amount_spin").set("value", 3)
	setup_panel.get("_price_spin").set("value", 4)
	setup_panel.call("_confirm_transfer")
	var draft_slots: Array = setup_panel.get("_stall_slots")
	_assert_equal(Inventory.get_count(PrototypeConstants.ITEM_APPLE), 2, "确认上架后背包应扣除对应数量")
	_assert_equal(int((draft_slots[0] as Dictionary).get("count", 0)), 3, "确认上架后摊位草稿应增加商品数量")
	_assert_equal(int((draft_slots[0] as Dictionary).get("price", 0)), 4, "确认上架后摊位草稿应记录单价")
	var empty_slot_index := _empty_backpack_slot_index()
	setup_panel.call("handle_slot_drop", {
		"source": "stall",
		"slot_index": 0,
		"slot": (draft_slots[0] as Dictionary).duplicate(),
	}, "backpack", empty_slot_index)
	_assert_equal(Inventory.get_count(PrototypeConstants.ITEM_APPLE), 5, "摊位格拖回背包后库存应守恒")
	_assert_true(((setup_panel.get("_stall_slots") as Array)[0] as Dictionary).is_empty(), "摊位格拖回背包后草稿格应清空")
	setup_panel.call("handle_slot_drop", {
		"source": "backpack",
		"slot_index": _slot_index_for(PrototypeConstants.ITEM_APPLE),
		"slot": Inventory.slots[_slot_index_for(PrototypeConstants.ITEM_APPLE)].duplicate(),
	}, "stall", 0)
	setup_panel.get("_amount_spin").set("value", 2)
	setup_panel.call("_confirm_transfer")
	setup_panel.call("cancel_setup")
	_assert_equal(Inventory.get_count(PrototypeConstants.ITEM_APPLE), 5, "取消摆摊准备应把草稿商品完整退回背包")
	setup_panel.call("hide_panel")
	setup_panel.queue_free()

	var stall := Node2D.new()
	stall.name = "OpenStall"
	stall.add_to_group("stall")
	stall.set_script(StallScript)
	var visual := Sprite2D.new()
	visual.name = "Visual"
	stall.add_child(visual)
	add_child(stall)
	await get_tree().process_frame
	Inventory.set_count(PrototypeConstants.ITEM_APPLE, 0)
	Inventory.set_count("cabbage", 0)

	var prepared_slots: Array[Dictionary] = [
		{"item_id": PrototypeConstants.ITEM_APPLE, "count": 12, "price": 5},
		{"item_id": "cabbage", "count": 3, "price": 1},
	]
	_assert_true(stall.call("open_with_slots", PrototypeConstants.SPOT_STREET, prepared_slots, null), "摊位应能用多商品格开摊")
	_assert_equal(stall.get("stock"), 15, "摊位兼容 stock 应等于所有商品总数，且不再限制总件数")
	_assert_equal((stall.get("stall_slots") as Array).size(), GameState.get_stall_slot_count(), "摊位实际格数应跟随等级")

	var customer_profile := {
		"label": "测试顾客",
		"budget": 5,
		"preferences": {
			PrototypeConstants.ITEM_APPLE: 0.5,
			"cabbage": 0.9,
		},
	}
	var decision: Dictionary = stall.call("can_sell_to", PrototypeConstants.CUSTOMER_WORKER, customer_profile)
	_assert_true(bool(decision.get("bought", false)), "多商品摊位应能根据顾客画像选出可购买商品")
	_assert_equal(str(decision.get("item_id", "")), "cabbage", "顾客应优先选择更偏好且更划算的商品")
	var cash_before_sale := GameState.cash
	var result: Dictionary = stall.call("sell_one", PrototypeConstants.CUSTOMER_WORKER, customer_profile)
	_assert_true(bool(result.get("bought", false)), "顾客应能完成多商品成交")
	_assert_equal(str(result.get("item_id", "")), "cabbage", "成交商品应来自被选中的摊位格")
	_assert_equal(GameState.cash, cash_before_sale + 1, "现金应按成交格价格增加")
	_assert_equal(stall.get("stock"), 14, "成交后总库存应减少 1")

	stall.call("close")
	_assert_equal(Inventory.get_count(PrototypeConstants.ITEM_APPLE), 12, "收摊后未卖苹果应返回背包")
	_assert_equal(Inventory.get_count("cabbage"), 2, "收摊后未卖白菜应返回背包")

	Inventory.set_count(PrototypeConstants.ITEM_APPLE, 0)
	Inventory.set_count("cabbage", 0)
	Inventory.configure_slot_count(1)
	Inventory.slots[0] = {"item_id": "cucumber", "count": 20}
	_assert_true(stall.call("open_with_slots", PrototypeConstants.SPOT_STREET, [{"item_id": PrototypeConstants.ITEM_APPLE, "count": 1, "price": 2}], null), "测试应能再次开摊")
	_assert_true(not bool(stall.call("close")), "背包满时收摊应失败")
	_assert_true(bool(stall.get("is_open")), "收摊失败时摊位应保持打开，避免丢货")
	_assert_equal(stall.get("stock"), 1, "收摊失败时摊位库存应保留")
	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)


func _slot_index_for(item_id: String) -> int:
	for index in range(Inventory.slots.size()):
		if str(Inventory.slots[index].get("item_id", "")) == item_id:
			return index
	return -1


func _empty_backpack_slot_index() -> int:
	for index in range(Inventory.slots.size()):
		if Inventory.slots[index].is_empty():
			return index
	return -1
