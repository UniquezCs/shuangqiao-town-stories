extends Node

const TOWN_SCENE := preload("res://scenes/town_scene.tscn")
const CustomerSchedule := preload("res://scripts/world/customer_schedule.gd")
const PricePanel := preload("res://scripts/ui/price_panel.gd")


func _ready() -> void:
	var price_panel := PricePanel.new()
	add_child(price_panel)
	await get_tree().process_frame
	price_panel.open(2)
	_assert_true(not get_tree().paused, "打开定价面板时不应暂停游戏")
	price_panel.hide_panel()
	price_panel.queue_free()

	var town := TOWN_SCENE.instantiate()
	add_child(town)
	await get_tree().process_frame

	var town_stall_spot := town.get_node_or_null("TownStallSpot")
	_assert_true(town_stall_spot != null, "镇街应提供一个覆盖全城的摆摊交互节点")
	_assert_true(town_stall_spot.is_in_group("interactable"), "全城摆摊交互节点应可交互")
	_assert_true(town_stall_spot.is_in_group("player_stall_spot"), "顾客应能找到玩家当前摊位节点")

	var south_stall_spot := town.get_node_or_null("SouthStallSpot")
	_assert_true(south_stall_spot != null, "镇街下方应提供第二片可摆摊区域")
	if south_stall_spot == null:
		return
	_assert_true(south_stall_spot.is_in_group("interactable"), "镇南摆摊区域应可交互")
	_assert_true(south_stall_spot.is_in_group("player_stall_spot"), "镇南摆摊区域应被顾客系统识别")
	_assert_true(south_stall_spot.global_position.y > town_stall_spot.global_position.y, "镇南摆摊区域应位于主街区域下方")

	var stall := south_stall_spot.get_node("Stall")
	Inventory.set_count(PrototypeConstants.ITEM_APPLE, 5)
	stall.global_position = Vector2.ZERO
	_assert_true(stall.call("open", PrototypeConstants.SPOT_SOUTH_STREET, 2), "应能打开镇南玩家摊位")
	var influence_area := stall.get_node_or_null("InfluenceArea") as Area2D
	_assert_true(influence_area != null, "开摊后应生成一个 Area2D 影响范围")
	if influence_area == null:
		return
	var influence_shape := influence_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_assert_true(influence_shape != null and influence_shape.shape is CircleShape2D, "影响范围应使用圆形 CollisionShape2D")

	var spawner := town.get_node("SchoolSpot/CustomerSpawner")
	_assert_equal(spawner.call("_player_stall_spot"), south_stall_spot, "顾客生成器应优先绑定当前已经开摊的摆摊区域")
	var residence_position: Vector2 = spawner.call("_residential_position")
	var destination_position := (spawner.get_parent() as Node2D).global_position + Vector2(0, 42)
	for index in range(4):
		var home_route: Dictionary = spawner.call("_route_for_mode", CustomerSchedule.ROUTE_HOME_TO_DESTINATION)
		_assert_equal(home_route["start"], residence_position, "NPC 从居民区生成时起点应固定，避免生成瞬移")
		_assert_equal(home_route["end"], destination_position, "NPC 去学校/工厂时终点应固定")
		var return_route: Dictionary = spawner.call("_route_for_mode", CustomerSchedule.ROUTE_DESTINATION_TO_HOME)
		_assert_equal(return_route["start"], destination_position, "NPC 从学校/工厂生成时起点应固定")
		_assert_equal(return_route["end"], residence_position, "NPC 回居民区时终点应固定")
	_assert_true(_has_varied_routes(spawner), "NPC 从居民区到学校/工厂的通勤路线不应固定")
	spawner.call("_spawn_customer", CustomerSchedule.ROUTE_HOME_TO_DESTINATION)
	await get_tree().process_frame

	var customers := find_children("Customer", "CharacterBody2D", true, false)
	_assert_equal(customers.size(), 1, "应该生成 1 个顾客")
	_assert_equal(customers[0].get_parent(), town, "顾客必须挂在 TownScene 下，切回家时才能随 TownScene 销毁")
	_assert_equal(customers[0].get("_tree_entered_position"), residence_position, "顾客进入场景树时就应在出生点，不能先显示在默认位置再瞬移")
	_assert_equal(customers[0].call("_active_stall"), null, "顾客进入影响范围前不应考虑摊位")
	influence_area.body_entered.emit(customers[0])
	_assert_equal(customers[0].call("_active_stall"), stall, "顾客进入影响范围后才应考虑摊位")

	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)


func _has_varied_routes(spawner: Node) -> bool:
	var signatures := {}
	for index in range(6):
		var route: Dictionary = spawner.call("_route_for_mode", CustomerSchedule.ROUTE_HOME_TO_DESTINATION)
		signatures[_route_signature(route)] = true
	return signatures.size() > 1


func _route_signature(route: Dictionary) -> String:
	var points: Array = route.get("points", [])
	var signature := "%s>%s" % [str(route.get("start", Vector2.ZERO).round()), str(route.get("end", Vector2.ZERO).round())]
	for point in points:
		signature += ">%s" % str((point as Vector2).round())
	return signature
