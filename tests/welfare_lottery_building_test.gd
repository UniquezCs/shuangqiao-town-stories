extends Node

const TOWN_SCENE := preload("res://scenes/town_scene.tscn")


func _ready() -> void:
	var town := TOWN_SCENE.instantiate()
	add_child(town)
	await get_tree().process_frame

	var shop := town.get_node_or_null("Buildings/WelfareLotteryShop")
	_assert_true(shop != null, "镇街应包含 WelfareLotteryShop 建筑")

	var ticket := shop.get_node_or_null("LotteryTicket")
	_assert_true(ticket != null, "WelfareLotteryShop 应组合 LotteryTicket 节点")
	_assert_true(ticket.has_method("buy_ticket"), "LotteryTicket 应提供购买彩票接口")

	var interaction := shop.get_node_or_null("LotteryInteraction")
	_assert_true(interaction != null, "WelfareLotteryShop 应组合彩票交互 Area")
	_assert_true(interaction.is_in_group("interactable"), "彩票交互 Area 应加入 interactable 组")
	_assert_true(interaction.has_method("interact"), "彩票交互 Area 应能响应玩家互动")

	town.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
