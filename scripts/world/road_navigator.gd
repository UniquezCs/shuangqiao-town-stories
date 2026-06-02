extends Node

@export var road_layer_path := NodePath("../MapLayers/RoadLayer")
@export var extra_road_layer_paths: Array[NodePath] = []
@export_range(1, 16, 1) var endpoint_candidate_radius_tiles := 5
@export_range(1, 24, 1) var endpoint_candidate_limit := 8
@export_range(0.0, 1.0, 0.05) var random_midpoint_chance := 0.35
@export_range(0, 24, 1) var random_midpoint_attempts := 8
@export var log_navigation_warnings := false

var _road_layer: TileMapLayer = null
var _road_cells: Array[Vector2i] = []
var _road_lookup: Dictionary = {}
var _astar := AStarGrid2D.new()
var _is_built := false


func _ready() -> void:
	add_to_group("road_navigator")
	rebuild()


func rebuild() -> void:
	_road_layer = get_node_or_null(road_layer_path) as TileMapLayer
	_road_cells.clear()
	_road_lookup.clear()
	_is_built = false

	if _road_layer == null:
		if log_navigation_warnings:
			push_warning("RoadNavigator 找不到 RoadLayer：%s" % str(road_layer_path))
		return

	_append_road_cells_from_layer(_road_layer)
	for path in extra_road_layer_paths:
		var extra_layer: TileMapLayer = get_node_or_null(path) as TileMapLayer
		if extra_layer == null:
			if log_navigation_warnings:
				push_warning("RoadNavigator 找不到额外道路层：%s" % str(path))
			continue
		_append_road_cells_from_layer(extra_layer)

	if _road_cells.is_empty():
		if log_navigation_warnings:
			push_warning("RoadNavigator 的 RoadLayer 没有绘制任何道路 tile")
		return

	var min_cell := _road_cells[0]
	var max_cell := _road_cells[0]
	for cell in _road_cells:
		min_cell.x = min(min_cell.x, cell.x)
		min_cell.y = min(min_cell.y, cell.y)
		max_cell.x = max(max_cell.x, cell.x)
		max_cell.y = max(max_cell.y, cell.y)
		_road_lookup[cell] = true

	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE)
	if _road_layer.tile_set != null:
		var tile_size := _road_layer.tile_set.tile_size
		_astar.cell_size = Vector2(tile_size.x, tile_size.y)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()

	for x in range(_astar.region.position.x, _astar.region.position.x + _astar.region.size.x):
		for y in range(_astar.region.position.y, _astar.region.position.y + _astar.region.size.y):
			_astar.set_point_solid(Vector2i(x, y), true)

	for cell in _road_cells:
		_astar.set_point_solid(cell, false)

	_is_built = true


func _append_road_cells_from_layer(layer: TileMapLayer) -> void:
	for source_cell: Vector2i in layer.get_used_cells():
		var world_position: Vector2 = layer.to_global(layer.map_to_local(source_cell))
		var primary_cell: Vector2i = _road_layer.local_to_map(_road_layer.to_local(world_position))
		if _road_lookup.has(primary_cell):
			continue
		_road_cells.append(primary_cell)
		_road_lookup[primary_cell] = true


func get_road_cell_count() -> int:
	_ensure_built()
	return _road_cells.size()


func has_road_cell(cell: Vector2i) -> bool:
	_ensure_built()
	return _road_lookup.has(cell)


func world_to_cell(world_position: Vector2) -> Vector2i:
	_ensure_built()
	if _road_layer == null:
		return Vector2i.ZERO
	return _road_layer.local_to_map(_road_layer.to_local(world_position))


func cell_to_world(cell: Vector2i) -> Vector2:
	_ensure_built()
	if _road_layer == null:
		return Vector2.ZERO
	return _road_layer.to_global(_road_layer.map_to_local(cell))


func closest_road_cell(world_position: Vector2) -> Vector2i:
	_ensure_built()
	if _road_cells.is_empty():
		return Vector2i.ZERO

	var requested_cell := world_to_cell(world_position)
	if _road_lookup.has(requested_cell):
		return requested_cell

	var best_cell := _road_cells[0]
	var best_distance := INF
	for cell in _road_cells:
		var distance := cell_to_world(cell).distance_squared_to(world_position)
		if distance < best_distance:
			best_distance = distance
			best_cell = cell
	return best_cell


func closest_road_point(world_position: Vector2) -> Vector2:
	return cell_to_world(closest_road_cell(world_position))


func find_path(start_world: Vector2, end_world: Vector2) -> Array[Vector2]:
	if not _ensure_built():
		return []
	var start_cell := closest_road_cell(start_world)
	var end_cell := closest_road_cell(end_world)
	return _cells_to_world(_path_cells(start_cell, end_cell))


func find_randomized_path(start_world: Vector2, end_world: Vector2, rng: RandomNumberGenerator = null) -> Array[Vector2]:
	if not _ensure_built():
		return []

	var route_rng := rng
	if route_rng == null:
		route_rng = RandomNumberGenerator.new()
		route_rng.randomize()

	var start_candidates := _candidate_cells(start_world)
	var end_candidates := _candidate_cells(end_world)
	if start_candidates.is_empty() or end_candidates.is_empty():
		return []

	var start_cell := start_candidates[0]
	var end_cell := end_candidates[0]
	var route_cells := _randomized_path_cells(start_cell, end_cell, route_rng)
	if not route_cells.is_empty():
		return _cells_to_world(route_cells)

	for candidate_start in start_candidates:
		for candidate_end in end_candidates:
			route_cells = _path_cells(candidate_start, candidate_end)
			if not route_cells.is_empty():
				return _cells_to_world(route_cells)

	return []


func _randomized_path_cells(start_cell: Vector2i, end_cell: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	if _road_cells.size() >= 3 and rng.randf() < random_midpoint_chance:
		for _attempt in range(random_midpoint_attempts):
			var midpoint := _road_cells[rng.randi_range(0, _road_cells.size() - 1)]
			if midpoint == start_cell or midpoint == end_cell:
				continue

			var first_leg := _path_cells(start_cell, midpoint)
			var second_leg := _path_cells(midpoint, end_cell)
			if first_leg.is_empty() or second_leg.is_empty():
				continue

			second_leg.remove_at(0)
			first_leg.append_array(second_leg)
			return _compress_cells(first_leg)

	return _path_cells(start_cell, end_cell)


func _candidate_cells(world_position: Vector2) -> Array[Vector2i]:
	var origin := world_to_cell(world_position)
	var candidates: Array[Vector2i] = []
	for x in range(origin.x - endpoint_candidate_radius_tiles, origin.x + endpoint_candidate_radius_tiles + 1):
		for y in range(origin.y - endpoint_candidate_radius_tiles, origin.y + endpoint_candidate_radius_tiles + 1):
			var cell := Vector2i(x, y)
			if _road_lookup.has(cell):
				candidates.append(cell)

	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return cell_to_world(a).distance_squared_to(world_position) < cell_to_world(b).distance_squared_to(world_position)
	)

	while candidates.size() > endpoint_candidate_limit:
		candidates.pop_back()
	return candidates


func _path_cells(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	if _road_cells.is_empty() or not _road_lookup.has(start_cell) or not _road_lookup.has(end_cell):
		return []
	if start_cell == end_cell:
		return [start_cell]

	var raw_path := _astar.get_id_path(start_cell, end_cell)
	var path: Array[Vector2i] = []
	for point in raw_path:
		path.append(point)
	return _compress_cells(path)


func _compress_cells(path: Array[Vector2i]) -> Array[Vector2i]:
	if path.size() <= 2:
		return path

	var compressed: Array[Vector2i] = [path[0]]
	var previous_direction := path[1] - path[0]
	for index in range(1, path.size() - 1):
		var next_direction := path[index + 1] - path[index]
		if next_direction != previous_direction:
			compressed.append(path[index])
		previous_direction = next_direction
	compressed.append(path.back())
	return compressed


func _cells_to_world(cells: Array[Vector2i]) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for cell in cells:
		points.append(cell_to_world(cell))
	return points


func _ensure_built() -> bool:
	if _is_built:
		return true
	rebuild()
	return _is_built
