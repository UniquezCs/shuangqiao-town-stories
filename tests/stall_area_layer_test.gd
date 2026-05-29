extends Node

const StallAreaLayerScript := preload("res://scripts/world/stall_area_layer.gd")


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
	_assert_equal(str(first.get("spot_id")), "stall_area_1", "自动生成的第一个区域应有稳定 spot_id")
	_assert_equal(str(first.get("label")), "摆摊区1", "自动生成的第一个区域应有稳定 label")

	var second := spots[1] as Node2D
	var second_shape := second.get_node("CollisionShape2D") as CollisionShape2D
	var second_rect := second_shape.shape as RectangleShape2D
	_assert_equal(second_rect.size, Vector2(64, 32), "2x1 tile 区域应生成 64x32 交互范围")
	_assert_equal(second_shape.global_position, layer.to_global(layer.map_to_local(Vector2i(4, 0)) + Vector2(16, 0)), "2x1 tile 区域碰撞中心应与 tile 包围盒中心对齐")

	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)
