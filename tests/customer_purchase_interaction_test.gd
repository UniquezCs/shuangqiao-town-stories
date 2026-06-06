extends Node

const CUSTOMER_SCENE := preload("res://scenes/customer.tscn")
const STALL_SPOT_SCENE := preload("res://scenes/stall_spot.tscn")
const StallScript := preload("res://scripts/world/stall.gd")
const StallSalesPolicy := preload("res://scripts/world/stall_sales_policy.gd")
const CustomerDialogueLines := preload("res://scripts/world/customer_dialogue_lines.gd")
const CustomerDialogueBubble := preload("res://scripts/world/customer_dialogue_bubble.gd")


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
	_assert_purchase_willingness_is_lowered()
	_assert_see_stall_lines_name_item()
	await _assert_dialogue_bubble_fades()

	var stall := TestStall.new()
	add_child(stall)

	var silent_customer := CUSTOMER_SCENE.instantiate()
	add_child(silent_customer)
	silent_customer.call("setup", PrototypeConstants.CUSTOMER_STUDENT, stall, Vector2.ZERO, Vector2(96, 0), [])
	await get_tree().process_frame
	_force_dialogue_chance(silent_customer, CustomerDialogueLines.EVENT_WAITING, 0.0)
	silent_customer.call("_begin_purchase_request", stall)
	_assert_true(silent_customer.get_node_or_null("DialogueBubble") == null, "对话概率为 0 时不应固定弹出购买等待短句")
	silent_customer.queue_free()

	var customer := CUSTOMER_SCENE.instantiate()
	add_child(customer)
	customer.call("setup", PrototypeConstants.CUSTOMER_STUDENT, stall, Vector2.ZERO, Vector2(96, 0), [])
	_force_common_dialogues(customer, 1.0)
	await get_tree().process_frame

	customer.call("_begin_purchase_request", stall)
	_assert_equal(customer.get("state"), "waiting_for_player", "顾客决定购买后应进入等待玩家确认状态")
	_assert_equal(stall.sold_count, 0, "进入等待状态时不应立刻完成交易")

	var interaction := customer.get_node_or_null("PurchaseInteraction") as Area2D
	_assert_true(interaction != null, "等待购买时应生成可交互 Area2D")
	_assert_true(interaction.is_in_group("interactable"), "购买确认 Area2D 应加入 interactable 组")
	_assert_equal(interaction.call("get_prompt"), "确认卖梨", "购买确认提示应根据实际商品变化")
	_assert_true(customer.get_node_or_null("DialogueBubble") != null, "等待购买时应显示头顶对话气泡")
	_assert_true(not str(customer.call("get_current_dialogue_text")).is_empty(), "购买等待气泡应有随机短句")

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
	_assert_true(not str(customer.call("get_current_dialogue_text")).is_empty(), "成交后应显示感谢类气泡")
	await get_tree().create_timer(0.5).timeout

	var timeout_stall := TestStall.new()
	add_child(timeout_stall)
	var timeout_customer := CUSTOMER_SCENE.instantiate()
	add_child(timeout_customer)
	timeout_customer.call("setup", PrototypeConstants.CUSTOMER_STUDENT, timeout_stall, Vector2.ZERO, Vector2(96, 0), [])
	_force_common_dialogues(timeout_customer, 1.0)
	await get_tree().process_frame
	timeout_customer.call("_begin_purchase_request", timeout_stall)
	timeout_customer.call("_on_purchase_timeout")
	_assert_equal(timeout_stall.sold_count, 0, "倒计时结束未互动时不应完成交易")
	_assert_equal(timeout_customer.get("state"), "leaving", "倒计时结束后顾客应离开")
	_assert_true(not str(timeout_customer.call("get_current_dialogue_text")).is_empty(), "倒计时结束后应显示离开短句")

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
	_force_common_dialogues(closing_customer, 1.0)
	closing_customer.set("_customer_profile", {
		"age_group": PrototypeConstants.CUSTOMER_AGE_MIDDLE,
		"gender": PrototypeConstants.CUSTOMER_GENDER_FEMALE,
		"label": "测试顾客",
		"budget": 5,
		"preferences": {"pear": 0.95},
	})
	await get_tree().process_frame
	closing_customer.call("_begin_purchase_request", real_stall)
	_assert_equal(closing_customer.get("state"), "waiting_for_player", "真实摊位顾客应进入等待购买")
	_assert_true(real_stall.call("close"), "真实摊位应能收摊")
	await get_tree().process_frame
	_assert_equal(closing_customer.get("state"), "leaving", "顾客等待购买时收摊应立刻离开")
	_assert_true(closing_customer.get_node_or_null("PurchaseInteraction") == null, "收摊后应清理顾客购买交互")
	_assert_true(closing_customer.get_node_or_null("PurchaseCountdown") == null, "收摊后应清理顾客购买倒计时")

	var sold_out_stall := Node2D.new()
	sold_out_stall.name = "SoldOutStall"
	sold_out_stall.set_script(StallScript)
	var sold_out_visual := Sprite2D.new()
	sold_out_visual.name = "Visual"
	sold_out_stall.add_child(sold_out_visual)
	add_child(sold_out_stall)
	await get_tree().process_frame
	_assert_true(sold_out_stall.call("open_with_slots", PrototypeConstants.SPOT_STREET, [{"item_id": "pear", "count": 1, "price": 3}], null), "测试应能打开只有 1 个梨的真实摊位")
	var sold_out_waiting_customer := CUSTOMER_SCENE.instantiate()
	add_child(sold_out_waiting_customer)
	sold_out_waiting_customer.call("setup", PrototypeConstants.CUSTOMER_WORKER, sold_out_stall, Vector2.ZERO, Vector2(96, 0), [], "", PrototypeConstants.CUSTOMER_AGE_MIDDLE, PrototypeConstants.CUSTOMER_GENDER_FEMALE)
	_force_common_dialogues(sold_out_waiting_customer, 1.0)
	sold_out_waiting_customer.set("_customer_profile", {
		"age_group": PrototypeConstants.CUSTOMER_AGE_MIDDLE,
		"gender": PrototypeConstants.CUSTOMER_GENDER_FEMALE,
		"label": "等待顾客",
		"budget": 5,
		"preferences": {"pear": 0.95},
	})
	await get_tree().process_frame
	sold_out_waiting_customer.call("_begin_purchase_request", sold_out_stall)
	_assert_equal(sold_out_waiting_customer.get("state"), "waiting_for_player", "售罄回归测试应先让顾客进入等待购买")
	_assert_true(sold_out_waiting_customer.get_node_or_null("PurchaseInteraction") != null, "等待购买时应有交互区域")
	var sold_out_result: Dictionary = sold_out_stall.call("sell_one", PrototypeConstants.CUSTOMER_WORKER, {
		"label": "抢先顾客",
		"budget": 5,
		"preferences": {"pear": 0.95},
	})
	_assert_true(bool(sold_out_result.get("bought", false)), "另一名顾客应能买走最后一个梨")
	await get_tree().process_frame
	_assert_equal(sold_out_waiting_customer.get("state"), "leaving", "等待购买时对应商品售罄，顾客应立刻离开")
	_assert_true(sold_out_waiting_customer.get_node_or_null("PurchaseInteraction") == null, "商品售罄后应清理等待顾客的购买交互")
	_assert_true(sold_out_waiting_customer.get_node_or_null("PurchaseCountdown") == null, "商品售罄后应清理等待顾客的倒计时")

	var collision_spot := STALL_SPOT_SCENE.instantiate()
	add_child(collision_spot)
	await get_tree().process_frame
	_assert_true(collision_spot.call("open_stall_with_slots", [{"item_id": "apple", "count": 1, "price": 2}]), "测试应能打开带碰撞的摊位")
	var collision_stall: Node = collision_spot.get_node("Stall")
	var approaching_customer := CUSTOMER_SCENE.instantiate()
	add_child(approaching_customer)
	approaching_customer.call("setup", PrototypeConstants.CUSTOMER_STUDENT, collision_spot, Vector2(0, 160), Vector2(0, 220), [])
	_force_common_dialogues(approaching_customer, 1.0)
	approaching_customer.set("_customer_profile", {
		"age_group": PrototypeConstants.CUSTOMER_AGE_YOUTH,
		"gender": PrototypeConstants.CUSTOMER_GENDER_MALE,
		"label": "测试顾客",
		"budget": 5,
		"preferences": {"apple": 0.95},
	})
	await get_tree().process_frame
	approaching_customer.call("enter_stall_influence", collision_stall)
	_assert_true(approaching_customer.get_node_or_null("DialogueBubble") != null, "顾客看到感兴趣的摊位时应显示头顶短句")
	for index in range(120):
		await get_tree().physics_frame
		if approaching_customer.get("state") == "waiting_for_player":
			break
	_assert_equal(approaching_customer.get("state"), "waiting_for_player", "顾客被摊位吸引后应停在可交易位置，不应被摊位碰撞卡住")

	var stale_item_stall := Node2D.new()
	stale_item_stall.name = "StaleItemStall"
	stale_item_stall.set_script(StallScript)
	var stale_visual := Sprite2D.new()
	stale_visual.name = "Visual"
	stale_item_stall.add_child(stale_visual)
	add_child(stale_item_stall)
	await get_tree().process_frame
	_assert_true(stale_item_stall.call("open_with_slots", PrototypeConstants.SPOT_STREET, [
		{"item_id": PrototypeConstants.ITEM_APPLE, "count": 1, "price": 2},
		{"item_id": PrototypeConstants.ITEM_PEAR, "count": 1, "price": 2},
	], null), "测试应能打开苹果和梨的真实摊位")
	stale_item_stall.call("sell_one", PrototypeConstants.CUSTOMER_WORKER, {
		"label": "测试顾客",
		"budget": 5,
		"preferences": {PrototypeConstants.ITEM_APPLE: 0.95, PrototypeConstants.ITEM_PEAR: 0.0},
	})
	var stale_item_customer := CUSTOMER_SCENE.instantiate()
	add_child(stale_item_customer)
	stale_item_customer.call("setup", PrototypeConstants.CUSTOMER_WORKER, stale_item_stall, Vector2.ZERO, Vector2(96, 0), [])
	_force_common_dialogues(stale_item_customer, 1.0)
	stale_item_customer.set("_customer_profile", {
		"age_group": PrototypeConstants.CUSTOMER_AGE_MIDDLE,
		"gender": PrototypeConstants.CUSTOMER_GENDER_FEMALE,
		"label": "测试顾客",
		"budget": 5,
		"preferences": {PrototypeConstants.ITEM_APPLE: 0.95, PrototypeConstants.ITEM_PEAR: 0.95},
	})
	await get_tree().process_frame
	stale_item_customer.call("enter_stall_influence", stale_item_stall)
	var stale_dialogue := str(stale_item_customer.call("get_current_dialogue_text"))
	_assert_true(stale_dialogue.contains("梨"), "苹果售完后，看到摊位短句应使用仍在售且有需求的梨")
	_assert_true(not stale_dialogue.contains("苹果"), "苹果售完后，看到摊位短句不应继续使用已售完的苹果")

	customer.queue_free()
	stall.queue_free()
	timeout_customer.queue_free()
	timeout_stall.queue_free()
	closing_customer.queue_free()
	real_stall.queue_free()
	sold_out_waiting_customer.queue_free()
	sold_out_stall.queue_free()
	approaching_customer.queue_free()
	collision_spot.queue_free()
	stale_item_customer.queue_free()
	stale_item_stall.queue_free()
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


func _assert_purchase_willingness_is_lowered() -> void:
	var slots := [{"item_id": "pear", "count": 1, "price": 4}]
	var medium_profile := {
		"label": "测试顾客",
		"budget": 4,
		"preferences": {"pear": 0.70},
	}
	var medium_decision := StallSalesPolicy.can_sell_to(true, 1, slots, "pear", 4, PrototypeConstants.CUSTOMER_WORKER, medium_profile)
	_assert_equal(bool(medium_decision.get("bought", false)), false, "中等偏好的顾客不应再轻易用满预算购买")
	_assert_equal(str(medium_decision.get("dialogue_event", "")), "price_reject", "价格拒绝应返回对话事件")

	var high_profile := {
		"label": "测试顾客",
		"budget": 5,
		"preferences": {"pear": 0.95},
	}
	var high_decision := StallSalesPolicy.can_sell_to(true, 1, slots, "pear", 4, PrototypeConstants.CUSTOMER_WORKER, high_profile)
	_assert_equal(bool(high_decision.get("bought", false)), true, "高偏好且预算足够的顾客仍应能购买")


func _assert_see_stall_lines_name_item() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260606
	var profile := {
		"age_group": PrototypeConstants.CUSTOMER_AGE_MIDDLE,
		"gender": PrototypeConstants.CUSTOMER_GENDER_FEMALE,
	}
	for index in range(64):
		var line := CustomerDialogueLines.line_for(CustomerDialogueLines.EVENT_SEE_STALL, profile, PrototypeConstants.ITEM_PEAR, 3, "", rng)
		_assert_true(line.contains("梨"), "看见摊位短句应始终点名当前感兴趣商品")


func _assert_dialogue_bubble_fades() -> void:
	var bubble := Node2D.new()
	bubble.name = "DialogueBubbleFadeTest"
	bubble.set_script(CustomerDialogueBubble)
	add_child(bubble)
	await get_tree().process_frame
	bubble.call("show_line", "淡入测试")
	_assert_true(bubble.visible, "对话气泡显示时应可见")
	_assert_true(float(bubble.modulate.a) <= 0.05, "对话气泡应从透明开始淡入")
	await get_tree().create_timer(0.18).timeout
	_assert_true(float(bubble.modulate.a) > 0.5, "对话气泡应在出现后淡入到可读状态")
	await get_tree().create_timer(2.85).timeout
	_assert_true(not bool(bubble.visible) or float(bubble.modulate.a) <= 0.05, "对话气泡停留后应淡出并隐藏")
	bubble.queue_free()


func _force_common_dialogues(customer: Node, chance: float) -> void:
	for event in [
		CustomerDialogueLines.EVENT_SEE_STALL,
		CustomerDialogueLines.EVENT_WAITING,
		CustomerDialogueLines.EVENT_BUDGET_REJECT,
		CustomerDialogueLines.EVENT_PRICE_REJECT,
		CustomerDialogueLines.EVENT_NO_INTEREST,
		CustomerDialogueLines.EVENT_PURCHASED,
		CustomerDialogueLines.EVENT_TIMEOUT,
		CustomerDialogueLines.EVENT_STALL_CLOSED,
	]:
		_force_dialogue_chance(customer, event, chance)


func _force_dialogue_chance(customer: Node, event: String, chance: float) -> void:
	_assert_true(customer.has_method("set_dialogue_chance_override"), "顾客应支持按事件覆盖对话触发概率，便于测试和调参")
	if customer.has_method("set_dialogue_chance_override"):
		customer.call("set_dialogue_chance_override", event, chance)
