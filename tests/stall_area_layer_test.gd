extends Node

const StallAreaLayerScript := preload("res://scripts/world/stall_area_layer.gd")
const STALL_SPOT_SCENE := preload("res://scenes/stall_spot.tscn")


func _ready() -> void:
	var world := Node2D.new()
	add_child(world)

	var layer := TileMapLayer.new()
	layer.name = "StallAreaLayer"
	layer.set_script(StallAreaLayerScript)
	layer.tile_set = load("res://assets/generated/tilesets/rural_town_32/rural_town_tileset_32.tres")

	layer.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
	layer.set_cell(Vector2i(1, 0), 0, Vector2i(0, 0))
	layer.set_cell(Vector2i(0, 1), 0, Vector2i(0, 0))
	layer.set_cell(Vector2i(1, 1), 0, Vector2i(0, 0))
	layer.set_cell(Vector2i(4, 0), 0, Vector2i(0, 0))
	layer.set_cell(Vector2i(5, 0), 0, Vector2i(0, 0))
	world.add_child(layer)

	await get_tree().process_frame
	await get_tree().process_frame

	var spots := get_tree().get_nodes_in_group("player_stall_spot")
	_assert_equal(spots.size(), 2, "StallAreaLayer 应按连通 tile 区域生成 2 个摆摊点")
	spots.sort_custom(func(a: Node, b: Node) -> bool:
		return str(a.get("spot_id")) < str(b.get("spot_id"))
	)

	var first := spots[0] as Node2D
	var first_shape := first.get_node("CollisionShape2D") as CollisionShape2D
	var first_rect := first_shape.shape as RectangleShape2D
	_assert_equal(first_rect.size, Vector2(64, 64), "2x2 tile 区域应生成 64x64 交互范围")
	_assert_equal(first_shape.global_position, layer.to_global(layer.map_to_local(Vector2i(0, 0)) + Vector2(16, 16)), "2x2 tile 区域碰撞中心应与 tile 包围盒中心对齐")
	_assert_static_body_waits_for_open_stall(first, "2x2 tile 区域")
	_assert_equal(str(first.get("spot_id")), "stall_area_1", "自动生成的第一个区域应有稳定 spot_id")
	_assert_equal(str(first.get("label")), "摆摊区1", "自动生成的第一个区域应有稳定 label")

	var second := spots[1] as Node2D
	var second_shape := second.get_node("CollisionShape2D") as CollisionShape2D
	var second_rect := second_shape.shape as RectangleShape2D
	_assert_equal(second_rect.size, Vector2(64, 32), "2x1 tile 区域应生成 64x32 交互范围")
	_assert_equal(second_shape.global_position, layer.to_global(layer.map_to_local(Vector2i(4, 0)) + Vector2(16, 0)), "2x1 tile 区域碰撞中心应与 tile 包围盒中心对齐")
	_assert_static_body_waits_for_open_stall(second, "2x1 tile 区域")

	var fake_player := Node2D.new()
	fake_player.global_position = Vector2(220, 96)
	world.add_child(fake_player)
	first.call("interact", fake_player)
	_assert_equal(bool(first.call("open_stall_with_slots", [{"item_id": PrototypeConstants.ITEM_APPLE, "count": 1, "price": 2}])), true, "测试应能在玩家当前位置打开摊位")
	_assert_equal((first.get_node("Stall") as Node2D).global_position, fake_player.global_position, "开摊后 Stall 应移动到玩家当前位置")
	_assert_static_body_follows_open_stall(first, "2x2 tile 区域")

	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_static_body_waits_for_open_stall(spot: Node2D, label: String) -> void:
	var static_shape := spot.get_node("StaticBody2D/CollisionShape2D") as CollisionShape2D
	_assert_equal(static_shape.disabled, true, "%s 未开摊时 StaticBody2D 应先禁用，避免挡住玩家" % label)


func _assert_static_body_follows_open_stall(spot: Node2D, label: String) -> void:
	var template := STALL_SPOT_SCENE.instantiate()
	var template_stall := template.get_node("Stall") as Node2D
	var template_static_shape := template.get_node("StaticBody2D/CollisionShape2D") as CollisionShape2D
	var expected_relative_position := template_static_shape.global_position - template_stall.global_position
	var expected_shape := template_static_shape.shape as RectangleShape2D

	var stall := spot.get_node("Stall") as Node2D
	var static_shape := spot.get_node("StaticBody2D/CollisionShape2D") as CollisionShape2D
	var static_rect := static_shape.shape as RectangleShape2D
	_assert_equal(static_shape.disabled, false, "%s 开摊后 StaticBody2D 应启用" % label)
	_assert_equal(static_rect.size, expected_shape.size, "%s 生成的 StaticBody2D 尺寸应沿用 StallSpot 模板" % label)
	_assert_equal(static_shape.global_position, stall.global_position + expected_relative_position, "%s 开摊后 StaticBody2D 位置应沿用模板中相对 Stall 的偏移" % label)
	template.queue_free()
