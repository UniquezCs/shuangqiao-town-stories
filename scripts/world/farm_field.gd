extends Area2D

const FARM_PLOT_SCENE := preload("res://scenes/farm_plot.tscn")
const CELL_SIZE := 32.0

@export var field_id := "home_field"


func _ready() -> void:
	SignalBus.current_tool_changed.connect(_on_current_tool_changed)
	_refresh_interactable_state()
	call_deferred("_restore_saved_plots")


func get_prompt() -> String:
	return "开垦脚下土地"


func interact(player: Node) -> void:
	if GameState.current_tool != PrototypeConstants.TOOL_HOE:
		return
	var player_node := player as Node2D
	if player_node == null:
		return
	var cell := _world_to_cell(player_node.global_position)
	if _has_plot_at_cell(cell):
		SignalBus.sale_feedback.emit("这格已经是农田", player_node.global_position)
		return
	var plot := FARM_PLOT_SCENE.instantiate()
	plot.name = "FarmPlot_%d_%d" % [cell.x, cell.y]
	var plot_id := _plot_id_for_cell(cell)
	plot.set("plot_id", plot_id)
	plot.global_position = _cell_to_world(cell)
	get_parent().add_child(plot)
	await get_tree().process_frame
	plot.call("_set_data", {
		"state": "tilled",
		"created": true,
		"cell_x": cell.x,
		"cell_y": cell.y,
	})
	GameState.set_objective("按 2 选择种子，在耕地上播种")
	SignalBus.sale_feedback.emit("开垦出一格新农田", plot.global_position)


func _world_to_cell(world_position: Vector2) -> Vector2i:
	var tile_layer := _tile_layer()
	if tile_layer != null:
		return tile_layer.local_to_map(tile_layer.to_local(world_position))
	return Vector2i(floori(world_position.x / CELL_SIZE), floori(world_position.y / CELL_SIZE))


func _cell_to_world(cell: Vector2i) -> Vector2:
	var tile_layer := _tile_layer()
	if tile_layer != null:
		return tile_layer.to_global(tile_layer.map_to_local(cell))
	return Vector2(float(cell.x) * CELL_SIZE + CELL_SIZE * 0.5, float(cell.y) * CELL_SIZE + CELL_SIZE * 0.5)


func _tile_layer() -> TileMapLayer:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("GroundLayer") as TileMapLayer


func _has_plot_at_cell(cell: Vector2i) -> bool:
	for node in get_tree().get_nodes_in_group("farm_plot"):
		var plot := node as Node2D
		if plot == null or not is_instance_valid(plot):
			continue
		if _world_to_cell(plot.global_position) == cell:
			return true
	return false


func _restore_saved_plots() -> void:
	for plot_id in GameState.farm_plot_states.keys():
		var id := str(plot_id)
		if not id.begins_with("%s_" % field_id):
			continue
		var data := GameState.get_farm_plot_data(id)
		if not bool(data.get("created", false)):
			continue
		var cell := Vector2i(int(data.get("cell_x", 0)), int(data.get("cell_y", 0)))
		if _has_plot_at_cell(cell):
			continue
		var plot := FARM_PLOT_SCENE.instantiate()
		plot.name = "FarmPlot_%d_%d" % [cell.x, cell.y]
		plot.set("plot_id", id)
		plot.global_position = _cell_to_world(cell)
		get_parent().add_child(plot)


func _plot_id_for_cell(cell: Vector2i) -> String:
	return "%s_%d_%d" % [field_id, cell.x, cell.y]


func _on_current_tool_changed(_tool_id: String) -> void:
	_refresh_interactable_state()


func _refresh_interactable_state() -> void:
	if GameState.current_tool == PrototypeConstants.TOOL_HOE:
		if not is_in_group("interactable"):
			add_to_group("interactable")
	elif is_in_group("interactable"):
		remove_from_group("interactable")
