extends Node

const BeggingSessionScript := preload("res://scripts/world/begging_session.gd")
const StallSpotScene := preload("res://scenes/stall_spot.tscn")
const PlayerScene := preload("res://scenes/player.tscn")


func _ready() -> void:
	GameState.reset_game()
	var player := PlayerScene.instantiate()
	add_child(player)
	await get_tree().process_frame

	var spot := StallSpotScene.instantiate()
	add_child(spot)
	await get_tree().process_frame

	spot.call("start_begging", player)
	_assert_true(bool(spot.call("is_begging_active")), "摆摊点应能进入乞讨状态")
	_assert_true(bool(player.call("is_begging")), "玩家进入乞讨后应被标记为乞讨状态")
	_assert_true(bool(spot.call("requires_hold_interact")), "乞讨状态应需要长按 E 才能退出")
	_assert_equal(float(spot.call("get_hold_interact_duration")), PrototypeConstants.BEGGING_STOP_HOLD_SECONDS, "乞讨退出长按时长应为 1 秒")

	var session := spot.get_node_or_null("BeggingSession")
	_assert_true(session != null, "进入乞讨后应生成 BeggingSession 节点")
	_assert_true(session.get_node_or_null("Bowl") != null, "乞讨会话应生成碗节点")
	_assert_true(session.get_node_or_null("BeggingInfluenceArea") != null, "乞讨会话应生成 Area2D 影响范围")

	var cash_before := GameState.cash
	var donor := Node2D.new()
	session.call("receive_donation", donor)
	donor.free()
	_assert_equal(GameState.cash, cash_before + 1, "NPC 捐钱后玩家现金应增加 1 元")
	_assert_true(player.get_node_or_null("SaleAmountPopup") != null, "NPC 捐钱后玩家头顶应显示 +1 元动效")
	await get_tree().create_timer(0.4).timeout

	spot.call("complete_hold_interact", player)
	await get_tree().process_frame
	_assert_true(not bool(spot.call("is_begging_active")), "长按完成后应退出乞讨状态")
	_assert_true(not bool(player.call("is_begging")), "退出乞讨后玩家应恢复可移动状态")
	spot.queue_free()
	player.queue_free()
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
