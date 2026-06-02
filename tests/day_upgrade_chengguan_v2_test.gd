extends Node

const StallScript := preload("res://scripts/world/stall.gd")
const ChengguanScript := preload("res://scripts/world/chengguan.gd")


func _ready() -> void:
	GameState.reset_game()
	GameState.cash = 200
	SignalBus.cash_changed.emit(GameState.cash)
	_assert_true(GameState.upgrade_backpack(), "现金足够时应能升级背包")
	_assert_equal(GameState.backpack_level, 2, "背包等级应提升")
	_assert_equal(Inventory.slot_count, GameState.get_backpack_slot_count(), "背包格数应跟随升级")
	_assert_true(GameState.upgrade_stall(), "现金足够时应能升级摊位")
	_assert_equal(GameState.stall_level, 2, "摊位等级应提升")

	GameState.record_sale(3)
	GameState.record_customer_served()
	var summary := GameState.end_day("sleep")
	_assert_equal(int(summary.get("income", 0)), 3, "睡觉日结应记录昨日收入")
	_assert_equal(GameState.current_game_minute, GameState.current_game_minute, "日结不应破坏时间字段")

	var stall := Node2D.new()
	stall.name = "OpenStall"
	stall.add_to_group("stall")
	stall.set_script(StallScript)
	var visual := Sprite2D.new()
	visual.name = "Visual"
	stall.add_child(visual)
	add_child(stall)
	await get_tree().process_frame
	Inventory.set_count(PrototypeConstants.ITEM_APPLE, 5)
	_assert_true(stall.call("open", PrototypeConstants.SPOT_STREET, 2, null), "应能打开摊位供城管检测")

	var chengguan := CharacterBody2D.new()
	chengguan.set_script(ChengguanScript)
	var cg_visual := AnimatedSprite2D.new()
	cg_visual.name = "Visual"
	chengguan.add_child(cg_visual)
	var detection := Area2D.new()
	detection.name = "DetectionArea"
	chengguan.add_child(detection)
	var catch_area := Area2D.new()
	catch_area.name = "CatchArea"
	chengguan.add_child(catch_area)
	add_child(chengguan)
	await get_tree().process_frame

	var player := CharacterBody2D.new()
	player.add_to_group("player")
	add_child(player)

	var target := stall.get_node_or_null("InspectionTarget")
	chengguan.call("_on_detection_area_entered", target)
	_assert_true(bool(stall.get("is_open")), "城管发现摊位后不应立即强制收摊")
	_assert_equal(chengguan.get("state"), "chasing", "城管发现摊位后应进入追击状态")
	_assert_equal(GameState.chengguan_caught_count, 0, "追到玩家前不应记录处罚")

	chengguan.call("_on_catch_area_body_entered", player)
	_assert_true(not bool(stall.get("is_open")), "城管追到玩家后应强制收摊")
	_assert_true(GameState.chengguan_caught_count >= 1, "城管处罚次数应记录")
	_assert_true(str(chengguan.get("_last_penalty_text")).contains("罚款"), "城管处罚后应记录罚款提示文案")
	_assert_true(PrototypeConstants.CHENGGUAN_CHASE_SPEED > 120.0, "城管追击速度应比玩家略快")

	GameState.reset_game()
	GameState.cash = 50
	Inventory.set_count(PrototypeConstants.ITEM_APPLE, 5)
	var second_stall := Node2D.new()
	second_stall.name = "SecondStall"
	second_stall.set_script(StallScript)
	var second_visual := Sprite2D.new()
	second_visual.name = "Visual"
	second_stall.add_child(second_visual)
	add_child(second_stall)
	await get_tree().process_frame
	_assert_true(second_stall.call("open", PrototypeConstants.SPOT_STREET, 2, null), "第二个摊位应能打开")

	var second_chengguan := CharacterBody2D.new()
	second_chengguan.set_script(ChengguanScript)
	var second_cg_visual := AnimatedSprite2D.new()
	second_cg_visual.name = "Visual"
	second_chengguan.add_child(second_cg_visual)
	var second_detection := Area2D.new()
	second_detection.name = "DetectionArea"
	second_chengguan.add_child(second_detection)
	var second_catch_area := Area2D.new()
	second_catch_area.name = "CatchArea"
	second_chengguan.add_child(second_catch_area)
	add_child(second_chengguan)
	await get_tree().process_frame

	second_chengguan.call("_on_detection_area_entered", second_stall.get_node_or_null("InspectionTarget"))
	second_stall.call("close")
	second_chengguan.call("_on_catch_area_body_entered", player)
	_assert_equal(GameState.chengguan_caught_count, 1, "被发现后即使已收摊，追到玩家也应处罚")
	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
