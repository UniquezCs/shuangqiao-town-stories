extends Node

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const StallSpotScript := preload("res://scripts/world/stall_spot.gd")
const StallScript := preload("res://scripts/world/stall.gd")


func _ready() -> void:
	GameState.reset_game()
	Inventory.set_count(PrototypeConstants.ITEM_APPLE, 0)

	var player := PLAYER_SCENE.instantiate()
	add_child(player)

	var spot := Area2D.new()
	spot.name = "TestStallSpot"
	spot.set_script(StallSpotScript)
	spot.set("spot_id", PrototypeConstants.SPOT_STREET)
	spot.set("label", "测试摊位")

	var stall := Node2D.new()
	stall.name = "Stall"
	stall.set_script(StallScript)
	var visual := Sprite2D.new()
	visual.name = "Visual"
	stall.add_child(visual)
	spot.add_child(stall)

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = RectangleShape2D.new()
	spot.add_child(collision)

	add_child(spot)
	await get_tree().process_frame
	_assert_true(spot.call("open_stall_with_slots", [{"item_id": PrototypeConstants.ITEM_APPLE, "count": 2, "price": 2}]), "测试应能打开摊位")
	_assert_true(stall.get("is_open"), "摊位应处于开摊状态")
	_assert_true(spot.has_method("requires_hold_interact") and bool(spot.call("requires_hold_interact")), "开摊状态下收摊交互应要求长按")

	spot.call("interact", player)
	_assert_true(stall.get("is_open"), "按一下 E 不应立刻收摊")

	player.call("_start_hold_interact", spot)
	var timer := player.get_node_or_null("StallCloseHoldTimer") as Timer
	_assert_true(timer != null, "长按收摊应创建 3 秒 Timer")
	_assert_equal(timer.wait_time, PrototypeConstants.STALL_CLOSE_HOLD_SECONDS, "收摊 Timer 应为 3 秒")
	var countdown := player.get_node_or_null("StallCloseCountdown") as Node2D
	_assert_true(countdown != null and countdown.has_method("set_remaining_fraction"), "玩家头顶应显示收摊圆形倒计时")
	_assert_true(stall.get("is_open"), "倒计时期间摊位仍应保持打开")

	player.call("_complete_hold_interact")
	await get_tree().process_frame
	_assert_true(not bool(stall.get("is_open")), "长按完成后才应收摊")
	_assert_true(player.get_node_or_null("StallCloseCountdown") == null, "收摊完成后应移除玩家头顶倒计时")

	player.queue_free()
	spot.queue_free()
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
