extends Node

const CUSTOMER_SCENE := preload("res://scenes/customer.tscn")
const CHENGGUAN_SCENE := preload("res://scenes/chengguan.tscn")


func _ready() -> void:
	await _test_customer_does_not_walk_forever_when_blocked()
	await _test_chengguan_does_not_walk_forever_when_blocked()
	get_tree().quit()


func _test_customer_does_not_walk_forever_when_blocked() -> void:
	var wall := _create_wall(Vector2(28, 0), Vector2(40, 120))
	add_child(wall)

	var customer := CUSTOMER_SCENE.instantiate()
	customer.call("setup", PrototypeConstants.CUSTOMER_STUDENT, null, Vector2(-24, 0), Vector2(120, 0), [])
	add_child(customer)
	await get_tree().process_frame

	for index in range(120):
		if not is_instance_valid(customer):
			break
		var route_points: Array = customer.get("_route_points")
		if route_points.size() > 1:
			break
		await get_tree().physics_frame

	_assert_true(
		is_instance_valid(customer),
		"顾客路径被碰撞挡住时，不应通过消失来恢复"
	)
	if not is_instance_valid(customer):
		wall.queue_free()
		await get_tree().process_frame
		return
	var customer_route_points: Array = customer.get("_route_points")
	_assert_true(
		customer_route_points.size() > 1,
		"顾客路径被碰撞挡住时，应插入绕行点继续前往原目标"
	)
	_assert_true(
		_has_side_detour(customer_route_points),
		"顾客绕行路径应偏离原直线路径"
	)
	wall.queue_free()
	if is_instance_valid(customer):
		customer.queue_free()
	await get_tree().process_frame


func _test_chengguan_does_not_walk_forever_when_blocked() -> void:
	var wall := _create_wall(Vector2(28, 0), Vector2(40, 120))
	add_child(wall)

	var chengguan := CHENGGUAN_SCENE.instantiate()
	var route_points: Array[Vector2] = [Vector2(120, 0)]
	var return_points: Array[Vector2] = []
	chengguan.call("setup", Vector2(-24, 0), route_points, return_points)
	add_child(chengguan)
	await get_tree().process_frame

	for index in range(120):
		if not is_instance_valid(chengguan):
			break
		var patrol_points: Array = chengguan.get("route_points")
		if patrol_points.size() > 1:
			break
		await get_tree().physics_frame

	_assert_true(
		is_instance_valid(chengguan),
		"城管路径被碰撞挡住时，不应通过消失来恢复"
	)
	if not is_instance_valid(chengguan):
		wall.queue_free()
		await get_tree().process_frame
		return
	var chengguan_route_points: Array = chengguan.get("route_points")
	_assert_true(
		chengguan_route_points.size() > 1,
		"城管路径被碰撞挡住时，应插入绕行点继续前往原目标"
	)
	_assert_true(
		_has_side_detour(chengguan_route_points),
		"城管绕行路径应偏离原直线路径"
	)
	wall.queue_free()
	if is_instance_valid(chengguan):
		chengguan.queue_free()
	await get_tree().process_frame


func _create_wall(center: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.name = "BlockingWall"
	wall.global_position = center
	wall.collision_layer = 3
	wall.collision_mask = 0
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	wall.add_child(shape_node)
	return wall


func _has_side_detour(points: Array) -> bool:
	for point in points:
		if abs((point as Vector2).y) > 24.0:
			return true
	return false


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
