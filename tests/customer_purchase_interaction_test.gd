extends Node

const CUSTOMER_SCENE := preload("res://scenes/customer.tscn")
const StallScript := preload("res://scripts/world/stall.gd")


class TestStall:
	extends Node2D

	var is_open := true
	var stock := 1
	var sold_count := 0

	func can_sell_to(_customer_type: String, _customer_profile: Dictionary = {}) -> Dictionary:
		return {"bought": true, "reason": "想买梨", "item_id": "pear", "price": 3, "slot_index": 0}

	func sell_one(_customer_type: String, _customer_profile: Dictionary = {}) -> Dictionary:
		sold_count += 1
		stock -= 1
		return {"bought": true, "reason": "测试成交", "item_id": "pear", "price": 3}


func _ready() -> void:
	var stall := TestStall.new()
	add_child(stall)

	var customer := CUSTOMER_SCENE.instantiate()
	add_child(customer)
	customer.call("setup", PrototypeConstants.CUSTOMER_STUDENT, stall, Vector2.ZERO, Vector2(96, 0), [])
	await get_tree().process_frame

	customer.call("_begin_purchase_request", stall)
	_assert_equal(customer.get("state"), "waiting_for_player", "顾客决定购买后应进入等待玩家确认状态")
	_assert_equal(stall.sold_count, 0, "进入等待状态时不应立刻完成交易")

	var interaction := customer.get_node_or_null("PurchaseInteraction") as Area2D
	_assert_true(interaction != null, "等待购买时应生成可交互 Area2D")
	_assert_true(interaction.is_in_group("interactable"), "购买确认 Area2D 应加入 interactable 组")

	var countdown := customer.get_node_or_null("PurchaseCountdown") as Node2D
	_assert_true(countdown != null and countdown.visible, "等待购买时头顶应显示商品倒计时图标")
	_assert_true(countdown.has_method("set_remaining_fraction"), "倒计时应使用圈形进度接口，而不是数字文本")
	_assert_true(customer.get_node_or_null("PurchaseCountdown/SecondsLabel") == null, "倒计时不应再显示数字 Label")
	var icon := customer.get_node_or_null("PurchaseCountdown/Icon") as Sprite2D
	_assert_true(icon != null, "倒计时应包含商品图标")
	_assert_equal(icon.texture.resource_path, ConfigLoader.get_item_icon("pear"), "顾客想买梨时应显示梨的图标")
	var timer := customer.get_node_or_null("PurchaseTimer") as Timer
	_assert_true(
		timer != null and timer.wait_time >= PrototypeConstants.CUSTOMER_PURCHASE_WAIT_MIN_SECONDS and timer.wait_time <= PrototypeConstants.CUSTOMER_PURCHASE_WAIT_MAX_SECONDS,
		"购买倒计时应在 5-10 秒之间"
	)

	interaction.call("interact", null)
	_assert_equal(stall.sold_count, 1, "玩家按 E 与顾客互动后才应完成交易")
	_assert_true(customer.get_node_or_null("PurchaseInteraction") == null, "完成交易后应移除购买交互 Area2D")
	await get_tree().create_timer(0.5).timeout

	var timeout_stall := TestStall.new()
	add_child(timeout_stall)
	var timeout_customer := CUSTOMER_SCENE.instantiate()
	add_child(timeout_customer)
	timeout_customer.call("setup", PrototypeConstants.CUSTOMER_STUDENT, timeout_stall, Vector2.ZERO, Vector2(96, 0), [])
	await get_tree().process_frame
	timeout_customer.call("_begin_purchase_request", timeout_stall)
	timeout_customer.call("_on_purchase_timeout")
	_assert_equal(timeout_stall.sold_count, 0, "倒计时结束未互动时不应完成交易")
	_assert_equal(timeout_customer.get("state"), "leaving", "倒计时结束后顾客应离开")

	var real_stall := Node2D.new()
	real_stall.name = "RealStall"
	real_stall.set_script(StallScript)
	var visual := Sprite2D.new()
	visual.name = "Visual"
	real_stall.add_child(visual)
	add_child(real_stall)
	await get_tree().process_frame
	_assert_true(real_stall.call("open_with_slots", PrototypeConstants.SPOT_STREET, [{"item_id": "pear", "count": 1, "price": 3}], null), "测试应能打开真实摊位")
	var closing_customer := CUSTOMER_SCENE.instantiate()
	add_child(closing_customer)
	closing_customer.call("setup", PrototypeConstants.CUSTOMER_WORKER, real_stall, Vector2.ZERO, Vector2(96, 0), [], "", PrototypeConstants.CUSTOMER_AGE_MIDDLE, PrototypeConstants.CUSTOMER_GENDER_FEMALE)
	await get_tree().process_frame
	closing_customer.call("_begin_purchase_request", real_stall)
	_assert_equal(closing_customer.get("state"), "waiting_for_player", "真实摊位顾客应进入等待购买")
	_assert_true(real_stall.call("close"), "真实摊位应能收摊")
	await get_tree().process_frame
	_assert_equal(closing_customer.get("state"), "leaving", "顾客等待购买时收摊应立刻离开")
	_assert_true(closing_customer.get_node_or_null("PurchaseInteraction") == null, "收摊后应清理顾客购买交互")
	_assert_true(closing_customer.get_node_or_null("PurchaseCountdown") == null, "收摊后应清理顾客购买倒计时")

	customer.queue_free()
	stall.queue_free()
	timeout_customer.queue_free()
	timeout_stall.queue_free()
	closing_customer.queue_free()
	real_stall.queue_free()
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
