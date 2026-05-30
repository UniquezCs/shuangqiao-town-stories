extends TileMapLayer

const STALL_SPOT_SCENE := preload("res://scenes/stall_spot.tscn")
const DEFAULT_TILE_SIZE := Vector2(32, 32)
const GENERATED_GROUP := "generated_stall_area_spot"

@export var base_spot_id := "stall_area"
@export var base_label := "摆摊区"
@export var hide_marker_layer_on_ready := true


func _ready() -> void:
	_generate_stall_spots()
	if hide_marker_layer_on_ready:
		visible = false


func _generate_stall_spots() -> void:
	_clear_generated_spots()
	var regions := _connected_regions(get_used_cells())
	for index in regions.size():
		_create_stall_spot(regions[index], index + 1)


func _clear_generated_spots() -> void:
	var parent_node := _generated_spot_parent()
	if parent_node == null:
		return
	for child in parent_node.get_children():
		if child.is_in_group(GENERATED_GROUP):
			child.queue_free()


func _create_stall_spot(cells: Array[Vector2i], area_index: int) -> void:
	if cells.is_empty():
		return
	var rect := _bounds_for(cells)
	var spot := STALL_SPOT_SCENE.instantiate() as Node2D
	spot.name = "%s%d" % [base_spot_id.to_pascal_case(), area_index]
	spot.add_to_group(GENERATED_GROUP)
	spot.set("spot_id", "%s_%d" % [base_spot_id, area_index])
	spot.set("label", "%s%d" % [base_label, area_index])
	spot.set("interaction_size", Vector2(rect.size) * _tile_size())
	spot.set("interaction_offset", _interaction_offset_for(rect))
	spot.position = Vector2.ZERO
	_generated_spot_parent().call_deferred("add_child", spot)


func _connected_regions(cells: Array[Vector2i]) -> Array:
	var remaining := {}
	for cell in cells:
		remaining[cell] = true

	var regions: Array = []
	while not remaining.is_empty():
		var start: Vector2i = remaining.keys()[0]
		var stack: Array[Vector2i] = [start]
		var region: Array[Vector2i] = []
		remaining.erase(start)

		while not stack.is_empty():
			var cell := stack.pop_back() as Vector2i
			region.append(cell)
			for neighbor in _neighbors(cell):
				if remaining.has(neighbor):
					remaining.erase(neighbor)
					stack.append(neighbor)

		regions.append(region)

	regions.sort_custom(_region_less)
	return regions


func _neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [
		cell + Vector2i.LEFT,
		cell + Vector2i.RIGHT,
		cell + Vector2i.UP,
		cell + Vector2i.DOWN,
	]


func _bounds_for(cells: Array[Vector2i]) -> Rect2i:
	var min_cell := cells[0]
	var max_cell := cells[0]
	for cell in cells:
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)
	return Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE)


func _region_less(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	var a_bounds := _bounds_for(a)
	var b_bounds := _bounds_for(b)
	if a_bounds.position.y == b_bounds.position.y:
		return a_bounds.position.x < b_bounds.position.x
	return a_bounds.position.y < b_bounds.position.y


func _interaction_offset_for(rect: Rect2i) -> Vector2:
	var tile_size := _tile_size()
	var first_center := map_to_local(rect.position)
	var half_span := Vector2(rect.size - Vector2i.ONE) * tile_size * 0.5
	return first_center + half_span


func _tile_size() -> Vector2:
	if tile_set != null:
		return Vector2(tile_set.tile_size)
	return DEFAULT_TILE_SIZE


func _generated_spot_parent() -> Node:
	var parent_node := get_parent()
	if parent_node != null and parent_node.name == "MapLayers" and parent_node.get_parent() != null:
		return parent_node.get_parent()
	return parent_node
