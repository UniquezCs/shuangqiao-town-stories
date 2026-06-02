extends Node2D

const HOME_SCENE := preload("res://scenes/home_scene.tscn")
const HOUSE_SCENE := preload("res://scenes/house_scene.tscn")
const TOWN_SCENE := preload("res://scenes/town_scene.tscn")

var current_world: Node2D = null
var pending_stall_spot: Node = null

@onready var world_root: Node2D = $WorldRoot
@onready var player: CharacterBody2D = $Player
@onready var price_panel: CanvasLayer = $PricePanel
@onready var shop_panel: CanvasLayer = $ShopPanel
@onready var stall_setup_panel: CanvasLayer = $StallSetupPanel
@onready var time_timer: Timer = $TimeWindowTimer


func _ready() -> void:
	SignalBus.scene_change_requested.connect(_on_scene_change_requested)
	SignalBus.price_panel_requested.connect(_on_price_panel_requested)
	SignalBus.stall_setup_requested.connect(_on_stall_setup_requested)
	SignalBus.shop_panel_requested.connect(_on_shop_panel_requested)
	price_panel.price_confirmed.connect(_on_price_confirmed)
	time_timer.timeout.connect(_advance_game_minute)
	GameState.reset_game()
	_start_day_clock()
	_load_world(PrototypeConstants.SCENE_HOUSE, "default")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tool_hoe"):
		GameState.set_current_tool(PrototypeConstants.TOOL_HOE)
	elif event.is_action_pressed("tool_seed"):
		GameState.set_current_tool(PrototypeConstants.TOOL_SEED)
	elif event.is_action_pressed("tool_water"):
		GameState.set_current_tool(PrototypeConstants.TOOL_WATER)
	elif event.is_action_pressed("tool_sickle"):
		GameState.set_current_tool(PrototypeConstants.TOOL_SICKLE)


func _on_scene_change_requested(target_scene: String, spawn_id: String) -> void:
	_load_world(target_scene, spawn_id)
	if target_scene == PrototypeConstants.SCENE_TOWN:
		_enter_town()
	elif target_scene == PrototypeConstants.SCENE_HOME:
		_enter_home()
	else:
		GameState.set_objective("出门劳作，晚上十二点前回来睡觉")


func _load_world(target_scene: String, spawn_id: String) -> void:
	if current_world != null:
		current_world.queue_free()
	current_world = _scene_for_id(target_scene).instantiate()
	world_root.add_child(current_world)
	GameState.current_scene = target_scene
	await get_tree().process_frame
	var spawn := current_world.get_node_or_null("Spawns/%s" % spawn_id)
	if spawn == null:
		spawn = current_world.get_node_or_null("Spawns/default")
	if spawn != null:
		player.global_position = spawn.global_position


func _on_price_panel_requested(stall_spot: Node) -> void:
	pending_stall_spot = stall_spot
	price_panel.open(2)


func _on_price_confirmed(price: int) -> void:
	if pending_stall_spot != null and is_instance_valid(pending_stall_spot):
		pending_stall_spot.call("open_stall", price)
	pending_stall_spot = null


func _on_stall_setup_requested(stall_spot: Node) -> void:
	pending_stall_spot = stall_spot
	stall_setup_panel.call("open_for_stall", stall_spot)


func _on_shop_panel_requested(shop: Node) -> void:
	shop_panel.call("open", shop)


func _start_day_clock() -> void:
	GameState.start_day_clock(PrototypeConstants.DAY_START_MINUTE)
	GameState.set_time_window(_time_window_for_minute(GameState.current_game_minute))
	if time_timer.is_stopped() and GameState.current_game_minute < PrototypeConstants.DAY_END_MINUTE:
		time_timer.start(PrototypeConstants.REAL_SECONDS_PER_GAME_MINUTE)


func _enter_town() -> void:
	_start_day_clock()
	GameState.set_objective("选择学校门口或厂门口摆摊")


func _enter_home() -> void:
	_start_day_clock()
	if GameState.objective.is_empty():
		GameState.set_objective("在家里播种苹果种子")


func _advance_game_minute() -> void:
	var next_minute := GameState.current_game_minute + 1
	GameState.set_game_time_minute(next_minute)
	GameState.set_time_window(_time_window_for_minute(next_minute))
	if next_minute >= PrototypeConstants.DAY_END_MINUTE:
		_force_next_day()
		return
	time_timer.start(PrototypeConstants.REAL_SECONDS_PER_GAME_MINUTE)


func _time_window_for_minute(total_minutes: int) -> String:
	if total_minutes >= PrototypeConstants.DAY_END_MINUTE:
		return PrototypeConstants.WINDOW_END
	if total_minutes >= 17 * 60:
		return PrototypeConstants.WINDOW_FACTORY
	if total_minutes >= 16 * 60:
		return PrototypeConstants.WINDOW_SCHOOL
	return PrototypeConstants.WINDOW_MORNING


func _force_next_day() -> void:
	time_timer.stop()
	_close_all_stalls()
	GameState.request_day_settlement(_remaining_apples())
	GameState.end_day("midnight")
	GameState.start_new_day(PrototypeConstants.DAY_START_MINUTE)
	await _load_world(PrototypeConstants.SCENE_HOUSE, "bed_spawn")
	time_timer.start(PrototypeConstants.REAL_SECONDS_PER_GAME_MINUTE)


func _close_all_stalls() -> void:
	for node in get_tree().get_nodes_in_group("stall"):
		if node.get("is_open"):
			node.call("close")


func _scene_for_id(target_scene: String) -> PackedScene:
	if target_scene == PrototypeConstants.SCENE_TOWN:
		return TOWN_SCENE
	if target_scene == PrototypeConstants.SCENE_HOUSE:
		return HOUSE_SCENE
	return HOME_SCENE


func _remaining_apples() -> int:
	var total := Inventory.get_count(PrototypeConstants.ITEM_APPLE)
	if current_world != null:
		for node in get_tree().get_nodes_in_group("stall"):
			if node.get("is_open"):
				total += int(node.get("stock"))
	return total
