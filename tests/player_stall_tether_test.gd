extends Node

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const StallScript := preload("res://scripts/world/stall.gd")


func _ready() -> void:
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
	var boundary := stall.get_node_or_null("PlayerBoundary") as StaticBody2D
	_assert_true(boundary != null, "开摊后应生成 PlayerBoundary 空气墙节点")
	if boundary == null:
		return
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
