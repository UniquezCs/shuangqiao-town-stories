extends RefCounted


static func create_influence_area(owner: Node, radius: float, body_entered_callback: Callable, body_exited_callback: Callable) -> Area2D:
	var influence_area := Area2D.new()
	influence_area.name = "InfluenceArea"
	influence_area.collision_layer = 0
	influence_area.collision_mask = 4
	influence_area.monitorable = false
	influence_area.monitoring = true
	influence_area.body_entered.connect(body_entered_callback)
	influence_area.body_exited.connect(body_exited_callback)

	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = radius
	collision_shape.shape = circle
	influence_area.add_child(collision_shape)
	owner.add_child(influence_area)
	return influence_area


static func create_inspection_target(owner: Node, radius: float) -> Area2D:
	var inspection_target := Area2D.new()
	inspection_target.name = "InspectionTarget"
	inspection_target.add_to_group("open_stall_inspection_target")
	inspection_target.collision_layer = 8
	inspection_target.collision_mask = 0
	inspection_target.monitoring = false
	inspection_target.monitorable = true

	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = radius
	collision_shape.shape = circle
	inspection_target.add_child(collision_shape)
	owner.add_child(inspection_target)
	return inspection_target


static func create_player_boundary(owner: Node) -> StaticBody2D:
	var player_boundary := StaticBody2D.new()
	player_boundary.name = "PlayerBoundary"
	player_boundary.collision_layer = PrototypeConstants.PLAYER_BOUNDARY_COLLISION_LAYER
	player_boundary.collision_mask = 0
	owner.add_child(player_boundary)

	var half_size := PrototypeConstants.STALL_PLAYER_BOUNDARY_HALF_SIZE
	var thickness := PrototypeConstants.STALL_PLAYER_BOUNDARY_WALL_THICKNESS
	_add_boundary_wall(player_boundary, Vector2(0, -half_size - thickness * 0.5), Vector2(half_size * 2.0 + thickness * 2.0, thickness))
	_add_boundary_wall(player_boundary, Vector2(0, half_size + thickness * 0.5), Vector2(half_size * 2.0 + thickness * 2.0, thickness))
	_add_boundary_wall(player_boundary, Vector2(-half_size - thickness * 0.5, 0), Vector2(thickness, half_size * 2.0))
	_add_boundary_wall(player_boundary, Vector2(half_size + thickness * 0.5, 0), Vector2(thickness, half_size * 2.0))
	return player_boundary


static func remove_runtime_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.queue_free()


static func _add_boundary_wall(player_boundary: StaticBody2D, local_position: Vector2, size: Vector2) -> void:
	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	collision_shape.position = local_position
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision_shape.shape = rectangle
	player_boundary.add_child(collision_shape)
