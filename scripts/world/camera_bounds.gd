extends Area2D

const BOUNDARY_WALLS_NAME := "BoundaryWalls"

@export var collision_shape_path := NodePath("CollisionShape2D")
@export var create_boundary_walls := false
@export_flags_2d_physics var boundary_wall_collision_layer := 1
@export_flags_2d_physics var boundary_wall_collision_mask := 0


func _ready() -> void:
	add_to_group("camera_bounds")
	if create_boundary_walls:
		rebuild_boundary_walls()


func apply_to_camera(camera: Camera2D) -> void:
	if camera == null:
		return
	var rect := get_bounds_rect()
	if rect.size == Vector2.ZERO:
		return
	camera.limit_left = int(floorf(rect.position.x))
	camera.limit_top = int(floorf(rect.position.y))
	camera.limit_right = int(ceilf(rect.position.x + rect.size.x))
	camera.limit_bottom = int(ceilf(rect.position.y + rect.size.y))


func get_bounds_rect() -> Rect2:
	var collision_shape := get_node_or_null(collision_shape_path) as CollisionShape2D
	if collision_shape == null:
		return Rect2()
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return Rect2()

	var shape_scale := Vector2(
		absf(collision_shape.global_scale.x),
		absf(collision_shape.global_scale.y)
	)
	var size := rectangle.size * shape_scale
	return Rect2(collision_shape.global_position - size * 0.5, size)


func rebuild_boundary_walls() -> void:
	var old_walls := get_node_or_null(BOUNDARY_WALLS_NAME)
	if old_walls != null:
		old_walls.free()

	var rect := _get_local_bounds_rect()
	if rect.size == Vector2.ZERO:
		return

	var walls := StaticBody2D.new()
	walls.name = BOUNDARY_WALLS_NAME
	walls.collision_layer = boundary_wall_collision_layer
	walls.collision_mask = boundary_wall_collision_mask
	add_child(walls)

	var left := rect.position.x
	var top := rect.position.y
	var right := rect.position.x + rect.size.x
	var bottom := rect.position.y + rect.size.y
	_add_segment_wall(walls, "TopWall", Vector2(left, top), Vector2(right, top))
	_add_segment_wall(walls, "RightWall", Vector2(right, top), Vector2(right, bottom))
	_add_segment_wall(walls, "BottomWall", Vector2(right, bottom), Vector2(left, bottom))
	_add_segment_wall(walls, "LeftWall", Vector2(left, bottom), Vector2(left, top))


func _get_local_bounds_rect() -> Rect2:
	var collision_shape := get_node_or_null(collision_shape_path) as CollisionShape2D
	if collision_shape == null:
		return Rect2()
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return Rect2()

	var shape_scale := Vector2(
		absf(collision_shape.scale.x),
		absf(collision_shape.scale.y)
	)
	var size := rectangle.size * shape_scale
	return Rect2(collision_shape.position - size * 0.5, size)


func _add_segment_wall(parent: StaticBody2D, wall_name: String, start: Vector2, end: Vector2) -> void:
	var shape := SegmentShape2D.new()
	shape.a = start
	shape.b = end

	var collision_shape := CollisionShape2D.new()
	collision_shape.name = wall_name
	collision_shape.shape = shape
	parent.add_child(collision_shape)
