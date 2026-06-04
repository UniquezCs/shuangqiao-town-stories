extends Node

const FARMING_CLICK_TOOLS := {
	PrototypeConstants.TOOL_HOE: true,
	PrototypeConstants.TOOL_SEED: true,
	PrototypeConstants.TOOL_WATER: true,
	PrototypeConstants.TOOL_SICKLE: true,
	PrototypeConstants.TOOL_FERTILIZER: true,
}

var player: Node2D = null


func setup(player_node: Node2D) -> void:
	player = player_node


func is_farming_click_tool(tool_id: String) -> bool:
	return FARMING_CLICK_TOOLS.has(tool_id)


func handle_click(world_position: Vector2) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if player.has_method("can_handle_farming_click") and not bool(player.call("can_handle_farming_click")):
		return false
	if not is_farming_click_tool(GameState.current_tool):
		return false
	var target := _nearest_farming_target(world_position)
	if target.is_empty():
		return false
	var target_position: Vector2 = target.get("world_position", world_position)
	if player.has_method("is_farming_target_in_reach") and not bool(player.call("is_farming_target_in_reach", target_position)):
		return false
	var target_node: Node = target.get("node", null)
	if target_node == null or not is_instance_valid(target_node) or not target_node.has_method("click_interact"):
		return false
	if player.has_method("face_towards_farming_target"):
		player.call("face_towards_farming_target", target_position)
	return bool(await target_node.call("click_interact", target_position, player))


func prompt_for_position(world_position: Vector2) -> String:
	if player == null or not is_instance_valid(player):
		return ""
	if not is_farming_click_tool(GameState.current_tool):
		return ""
	var target := _nearest_farming_target(world_position)
	if target.is_empty():
		return ""
	var target_position: Vector2 = target.get("world_position", world_position)
	if player.has_method("is_farming_target_in_reach") and not bool(player.call("is_farming_target_in_reach", target_position)):
		return "左键：目标太远"
	var target_node: Node = target.get("node", null)
	if target_node == null or not is_instance_valid(target_node):
		return ""
	var prompt := _prompt_for_target(target_node)
	return "" if prompt.is_empty() else "左键：%s" % prompt


func _nearest_farming_target(world_position: Vector2) -> Dictionary:
	if GameState.current_tool == PrototypeConstants.TOOL_HOE:
		return _nearest_farm_field_target(world_position)
	return _nearest_farm_plot_target(world_position)


func _nearest_farm_field_target(world_position: Vector2) -> Dictionary:
	var nearest := {}
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("farm_field"):
		if not is_instance_valid(node) or not node.has_method("nearest_click_target"):
			continue
		var target: Dictionary = node.call("nearest_click_target", world_position)
		if target.is_empty():
			continue
		var target_position: Vector2 = target.get("world_position", world_position)
		var distance := world_position.distance_to(target_position)
		if distance < nearest_distance:
			nearest = target
			nearest_distance = distance
	return nearest


func _nearest_farm_plot_target(world_position: Vector2) -> Dictionary:
	var nearest_plot: Node2D = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("farm_plot"):
		var plot := node as Node2D
		if plot == null or not is_instance_valid(plot):
			continue
		var distance := world_position.distance_to(plot.global_position)
		if distance < nearest_distance:
			nearest_plot = plot
			nearest_distance = distance
	if nearest_plot == null:
		return {}
	if nearest_distance > PrototypeConstants.FARM_CLICK_TARGET_RADIUS:
		return {}
	return {
		"world_position": nearest_plot.global_position,
		"node": nearest_plot,
	}


func _prompt_for_target(target_node: Node) -> String:
	if GameState.current_tool == PrototypeConstants.TOOL_HOE and target_node.is_in_group("farm_field"):
		return "开垦土地"
	if target_node.has_method("get_prompt"):
		return str(target_node.call("get_prompt"))
	return ""
