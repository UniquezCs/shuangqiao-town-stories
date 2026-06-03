extends Node

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const StallScript := preload("res://scripts/world/stall.gd")


func _ready() -> void:
	GameState.reset_game()
	GameState.cash = 200
	_assert_true(GameState.upgrade_stall(), "测试应能升级到 2 级摊位")

	var player := PLAYER_SCENE.instantiate()
	add_child(player)

	var stall := Node2D.new()
	stall.name = "OpenStall"
	stall.add_to_group("stall")
	stall.global_position = Vector2.ZERO
	stall.set_script(StallScript)
	var visual := Sprite2D.new()
	visual.name = "Visual"
	stall.add_child(visual)
	add_child(stall)
	await get_tree().process_frame

	Inventory.set_count(PrototypeConstants.ITEM_APPLE, 5)
	_assert_true(stall.call("open", PrototypeConstants.SPOT_STREET, 2, player), "应能打开摊位")
	_assert_equal(stall.get("influence_radius"), GameState.get_stall_influence_radius(), "摊位影响范围应从 upgrades.json 当前等级配置读取")
	var boundary := stall.get_node_or_null("PlayerBoundary") as StaticBody2D
	_assert_true(boundary != null, "开摊后应生成 PlayerBoundary 空气墙节点")
	if boundary == null:
		return
	var inspection_target := stall.get_node_or_null("InspectionTarget") as Area2D
	_assert_true(inspection_target != null, "开摊后应生成城管检测目标")
	var inspection_shape_node := inspection_target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var inspection_shape := inspection_shape_node.shape as CircleShape2D
	_assert_equal(inspection_shape.radius, GameState.get_stall_influence_radius(), "城管检测目标范围应和摊位影响范围配置一致")
	var influence_area := stall.get_node_or_null("InfluenceArea") as Area2D
	var influence_shape_node := influence_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var influence_shape := influence_shape_node.shape as CircleShape2D
	_assert_equal(influence_shape.radius, GameState.get_stall_influence_radius(), "顾客影响范围应和摊位影响范围配置一致")
	_assert_equal(boundary.collision_layer, PrototypeConstants.PLAYER_BOUNDARY_COLLISION_LAYER, "空气墙应使用玩家专用碰撞层，避免挡住城管")
	_assert_true(boundary.get_child_count() >= 4, "空气墙应由多个 CollisionShape2D 边界组成")
	for child in boundary.get_children():
		_assert_true(child is CollisionShape2D, "PlayerBoundary 的子节点应是碰撞形状")
	_assert_true(not player.has_method("_restrict_to_open_stall"), "玩家摆摊限制不应通过逐帧位置夹取实现")

	stall.call("close")
	await get_tree().process_frame
	_assert_true(stall.get_node_or_null("PlayerBoundary") == null, "收摊后应移除 PlayerBoundary 空气墙节点")

	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
