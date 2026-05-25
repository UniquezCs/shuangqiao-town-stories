extends Node2D

const HOME_SCENE := preload("res://scenes/home_scene.tscn")
const TOWN_SCENE := preload("res://scenes/town_scene.tscn")

var current_world: Node2D = null
var pending_stall_spot: Node = null
var time_index := 0
var time_windows := [
	PrototypeConstants.WINDOW_MORNING,
	PrototypeConstants.WINDOW_SCHOOL,
	PrototypeConstants.WINDOW_FACTORY,
	PrototypeConstants.WINDOW_END,
]

@onready var world_root: Node2D = $WorldRoot
@onready var player: CharacterBody2D = $Player
@onready var price_panel: CanvasLayer = $PricePanel
@onready var time_timer: Timer = $TimeWindowTimer


func _ready() -> void:
	SignalBus.scene_change_requested.connect(_on_scene_change_requested)
	SignalBus.price_panel_requested.connect(_on_price_panel_requested)
	price_panel.price_confirmed.connect(_on_price_confirmed)
	time_timer.timeout.connect(_advance_time_window)
	GameState.reset_game()
	_load_world(PrototypeConstants.SCENE_HOME, "default")


func _on_scene_change_requested(target_scene: String, spawn_id: String) -> void:
	_load_world(target_scene, spawn_id)
	if target_scene == PrototypeConstants.SCENE_TOWN:
		_start_business_time()
	else:
		time_timer.stop()
		GameState.set_time_window(PrototypeConstants.WINDOW_PREP)


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


func _start_business_time() -> void:
	time_index = 0
	GameState.set_time_window(time_windows[time_index])
	time_timer.start(_duration_for_window(GameState.current_time_window))
	GameState.set_objective("选择学校门口或厂门口摆摊")


func _advance_time_window() -> void:
	time_index += 1
	if time_index >= time_windows.size():
		time_index = time_windows.size() - 1
	var next_window: String = time_windows[time_index]
	GameState.set_time_window(next_window)
	if next_window == PrototypeConstants.WINDOW_END:
		time_timer.stop()
		GameState.request_day_settlement(_remaining_apples())
		GameState.set_objective("日终结算；可回家买种子")
	else:
		time_timer.start(_duration_for_window(next_window))


func _duration_for_window(window_id: String) -> float:
	match window_id:
		PrototypeConstants.WINDOW_MORNING:
			return 120.0
		PrototypeConstants.WINDOW_SCHOOL:
			return 180.0
		PrototypeConstants.WINDOW_FACTORY:
			return 180.0
	return 0.1


func _remaining_apples() -> int:
	var total := Inventory.get_count(PrototypeConstants.ITEM_APPLE)
	if current_world != null:
		for node in get_tree().get_nodes_in_group("stall"):
			if node.get("is_open"):
				total += int(node.get("stock"))
	return total
