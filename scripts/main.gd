extends Node2D

const HOME_SCENE := preload("res://scenes/home_scene.tscn")
const TOWN_SCENE := preload("res://scenes/town_scene.tscn")
const REAL_SECONDS_PER_GAME_MINUTE := 5.0
const DAY_START_MINUTE := 6 * 60
const DAY_END_MINUTE := 19 * 60

var current_world: Node2D = null
var pending_stall_spot: Node = null
var _settlement_requested := false

@onready var world_root: Node2D = $WorldRoot
@onready var player: CharacterBody2D = $Player
@onready var price_panel: CanvasLayer = $PricePanel
@onready var shop_panel: CanvasLayer = $ShopPanel
@onready var time_timer: Timer = $TimeWindowTimer


func _ready() -> void:
	SignalBus.scene_change_requested.connect(_on_scene_change_requested)
	SignalBus.price_panel_requested.connect(_on_price_panel_requested)
	SignalBus.shop_panel_requested.connect(_on_shop_panel_requested)
	price_panel.price_confirmed.connect(_on_price_confirmed)
	time_timer.timeout.connect(_advance_game_minute)
	GameState.reset_game()
	_start_day_clock()
	_load_world(PrototypeConstants.SCENE_HOME, "default")


func _on_scene_change_requested(target_scene: String, spawn_id: String) -> void:
	_load_world(target_scene, spawn_id)
	if target_scene == PrototypeConstants.SCENE_TOWN:
		_enter_town()
	else:
		_enter_home()


func _load_world(target_scene: String, spawn_id: String) -> void:
	if current_world != null:
		current_world.queue_free()
	current_world = (HOME_SCENE if target_scene == PrototypeConstants.SCENE_HOME else TOWN_SCENE).instantiate()
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


func _on_shop_panel_requested(shop: Node) -> void:
	shop_panel.call("open", shop)


func _start_day_clock() -> void:
	GameState.start_day_clock(DAY_START_MINUTE)
	GameState.set_time_window(_time_window_for_minute(GameState.current_game_minute))
	if time_timer.is_stopped() and GameState.current_game_minute < DAY_END_MINUTE:
		time_timer.start(REAL_SECONDS_PER_GAME_MINUTE)


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
	if next_minute >= DAY_END_MINUTE:
		time_timer.stop()
		if not _settlement_requested:
			_settlement_requested = true
			GameState.request_day_settlement(_remaining_apples())
			GameState.set_objective("日终结算；可回家买种子")
		return
	time_timer.start(REAL_SECONDS_PER_GAME_MINUTE)


func _time_window_for_minute(total_minutes: int) -> String:
	if total_minutes >= DAY_END_MINUTE:
		return PrototypeConstants.WINDOW_END
	if total_minutes >= 17 * 60:
		return PrototypeConstants.WINDOW_FACTORY
	if total_minutes >= 16 * 60:
		return PrototypeConstants.WINDOW_SCHOOL
	return PrototypeConstants.WINDOW_MORNING


func _remaining_apples() -> int:
	var total := Inventory.get_count(PrototypeConstants.ITEM_APPLE)
	if current_world != null:
		for node in get_tree().get_nodes_in_group("stall"):
			if node.get("is_open"):
				total += int(node.get("stock"))
	return total
