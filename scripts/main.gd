extends Node2D

const HOME_SCENE := preload("res://scenes/home_scene.tscn")
const HOUSE_SCENE := preload("res://scenes/house_scene.tscn")
const TOWN_SCENE := preload("res://scenes/town_scene.tscn")
const BACK_MOUNTAIN_SCENE := preload("res://scenes/back_mountain_scene.tscn")
const StallActionPanelScript := preload("res://scripts/ui/stall_action_panel.gd")
const LotteryPanelScript := preload("res://scripts/ui/lottery_panel.gd")

const SCENE_ENTRY_HOME := "home"
const SCENE_ENTRY_TOWN := "town"
const SCENE_ENTRY_BACK_MOUNTAIN := "back_mountain"
const SCENE_ENTRY_DEFAULT := "default"
const SCENE_ROUTES := {
	PrototypeConstants.SCENE_HOME: {
		"scene": HOME_SCENE,
		"entry": SCENE_ENTRY_HOME,
	},
	PrototypeConstants.SCENE_HOUSE: {
		"scene": HOUSE_SCENE,
		"entry": SCENE_ENTRY_DEFAULT,
	},
	PrototypeConstants.SCENE_TOWN: {
		"scene": TOWN_SCENE,
		"entry": SCENE_ENTRY_TOWN,
	},
	PrototypeConstants.SCENE_BACK_MOUNTAIN: {
		"scene": BACK_MOUNTAIN_SCENE,
		"entry": SCENE_ENTRY_BACK_MOUNTAIN,
		"objective": "在后山探索可采集区域",
	},
}

var current_world: Node2D = null
var pending_stall_spot: Node = null
var stall_action_panel: CanvasLayer = null
var lottery_panel: CanvasLayer = null
var _sleep_transition_layer: CanvasLayer = null
var _sleep_transition_rect: ColorRect = null
var _sleep_transition_running := false
var _sleep_transition_seconds := PrototypeConstants.SLEEP_TRANSITION_SECONDS
var _scene_transition_running := false
var _scene_transition_seconds := PrototypeConstants.SCENE_TRANSITION_SECONDS
var _startup_spawn_id := "default"

@onready var world_root: Node2D = $WorldRoot
@onready var player: CharacterBody2D = $Player
@onready var price_panel: CanvasLayer = $PricePanel
@onready var shop_panel: CanvasLayer = $ShopPanel
@onready var stall_setup_panel: CanvasLayer = $StallSetupPanel
@onready var daily_summary_panel: CanvasLayer = $DailySummaryPanel
@onready var time_timer: Timer = $TimeWindowTimer


func _ready() -> void:
	SignalBus.scene_change_requested.connect(_on_scene_change_requested)
	SignalBus.price_panel_requested.connect(_on_price_panel_requested)
	SignalBus.stall_action_requested.connect(_on_stall_action_requested)
	SignalBus.stall_setup_requested.connect(_on_stall_setup_requested)
	SignalBus.shop_panel_requested.connect(_on_shop_panel_requested)
	SignalBus.lottery_panel_requested.connect(_on_lottery_panel_requested)
	SignalBus.sleep_requested.connect(_on_sleep_requested)
	_create_stall_action_panel()
	_create_lottery_panel()
	_create_sleep_transition_overlay()
	price_panel.price_confirmed.connect(_on_price_confirmed)
	time_timer.timeout.connect(_advance_game_minute)
	_initialize_game_state()
	PopulationFlow.initialize_from_scene(TOWN_SCENE, true)
	_start_day_clock()
	_load_startup_world.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	var hotbar_index := _hotbar_index_from_event(event)
	if hotbar_index >= 0:
		Hotbar.select_slot(hotbar_index)
		get_viewport().set_input_as_handled()


func _on_scene_change_requested(target_scene: String, spawn_id: String) -> void:
	if _sleep_transition_running or _scene_transition_running:
		return
	_run_scene_transition(target_scene, spawn_id)


func _run_scene_transition(target_scene: String, spawn_id: String) -> void:
	_scene_transition_running = true
	_set_player_transition_locked(true)
	await _fade_sleep_overlay(0.0, 1.0, _scene_transition_seconds * 0.5)
	await _load_world(target_scene, spawn_id)
	_apply_scene_entry_state(target_scene)
	await _fade_sleep_overlay(1.0, 0.0, _scene_transition_seconds * 0.5)
	if _sleep_transition_rect != null:
		_sleep_transition_rect.visible = false
	_set_player_transition_locked(false)
	_scene_transition_running = false


func _apply_scene_entry_state(target_scene: String) -> void:
	var route := _scene_route_for_id(target_scene)
	match str(route.get("entry", SCENE_ENTRY_DEFAULT)):
		SCENE_ENTRY_TOWN:
			_enter_town()
		SCENE_ENTRY_HOME:
			_enter_home()
		SCENE_ENTRY_BACK_MOUNTAIN:
			GameState.set_objective(str(route.get("objective", "")))
		_:
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
		player.reset_physics_interpolation()
		await _snap_player_camera_to_player()


func _load_startup_world() -> void:
	await _load_world(GameState.current_scene, _startup_spawn_id)


func _on_price_panel_requested(stall_spot: Node) -> void:
	pending_stall_spot = stall_spot
	price_panel.open(2)


func _on_price_confirmed(price: int) -> void:
	if pending_stall_spot != null and is_instance_valid(pending_stall_spot):
		pending_stall_spot.call("open_stall", price)
	pending_stall_spot = null


func _on_stall_action_requested(stall_spot: Node) -> void:
	pending_stall_spot = stall_spot
	stall_action_panel.call("open", stall_spot)


func _on_stall_action_stall_selected(stall_spot: Node) -> void:
	_on_stall_setup_requested(stall_spot)


func _on_stall_action_begging_selected(stall_spot: Node) -> void:
	if stall_spot != null and is_instance_valid(stall_spot) and stall_spot.has_method("start_begging"):
		stall_spot.call("start_begging", player)


func _on_stall_setup_requested(stall_spot: Node) -> void:
	pending_stall_spot = stall_spot
	stall_setup_panel.call("open_for_stall", stall_spot)


func _on_shop_panel_requested(shop: Node) -> void:
	shop_panel.call("open", shop)


func _on_lottery_panel_requested(lottery: Node) -> void:
	lottery_panel.call("open", lottery)


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
	SaveManager.save_autosave()
	time_timer.start(PrototypeConstants.REAL_SECONDS_PER_GAME_MINUTE)


func _on_sleep_requested() -> void:
	if _sleep_transition_running:
		return
	_run_sleep_transition()


func _run_sleep_transition() -> void:
	_sleep_transition_running = true
	time_timer.stop()
	_close_all_stalls()
	if daily_summary_panel.has_method("defer_next_summary"):
		daily_summary_panel.call("defer_next_summary")
	await _fade_sleep_overlay(0.0, 1.0, _sleep_transition_seconds * 0.5)
	SignalBus.day_settlement_requested.emit()
	GameState.end_day("sleep")
	GameState.start_new_day(PrototypeConstants.DAY_START_MINUTE)
	await _load_world(PrototypeConstants.SCENE_HOUSE, "bed_spawn")
	SaveManager.save_autosave()
	await _fade_sleep_overlay(1.0, 0.0, _sleep_transition_seconds * 0.5)
	if _sleep_transition_rect != null:
		_sleep_transition_rect.visible = false
	_sleep_transition_running = false
	if daily_summary_panel.has_method("show_pending_summary"):
		daily_summary_panel.call("show_pending_summary")
	time_timer.start(PrototypeConstants.REAL_SECONDS_PER_GAME_MINUTE)


func is_sleep_transition_running() -> bool:
	return _sleep_transition_running


func is_scene_transition_running() -> bool:
	return _scene_transition_running


func set_sleep_transition_seconds_for_test(seconds: float) -> void:
	_sleep_transition_seconds = maxf(0.0, seconds)


func set_scene_transition_seconds_for_test(seconds: float) -> void:
	_scene_transition_seconds = maxf(0.0, seconds)


func get_player_camera_screen_center_for_test() -> Vector2:
	var camera := _get_player_camera()
	if camera == null:
		return Vector2.INF
	return camera.get_screen_center_position()


func _fade_sleep_overlay(from_alpha: float, to_alpha: float, duration: float) -> void:
	if _sleep_transition_rect == null:
		return
	_sleep_transition_rect.visible = true
	_sleep_transition_rect.color = Color(0.0, 0.0, 0.0, from_alpha)
	if duration <= 0.0:
		_sleep_transition_rect.color = Color(0.0, 0.0, 0.0, to_alpha)
		return
	var tween := create_tween()
	tween.tween_property(_sleep_transition_rect, "color:a", to_alpha, duration)
	await tween.finished


func _set_player_transition_locked(locked: bool) -> void:
	if player == null:
		return
	if locked:
		player.velocity = Vector2.ZERO
	player.set_physics_process(not locked)


func _snap_player_camera_to_player() -> void:
	var camera := _get_player_camera()
	if camera == null:
		return
	var smoothing_was_enabled := camera.position_smoothing_enabled
	camera.position_smoothing_enabled = false
	camera.reset_physics_interpolation()
	camera.reset_smoothing()
	camera.force_update_scroll()
	await get_tree().physics_frame
	camera.reset_smoothing()
	camera.force_update_scroll()
	camera.position_smoothing_enabled = smoothing_was_enabled


func _get_player_camera() -> Camera2D:
	if player == null:
		return null
	return player.get_node_or_null("Camera2D") as Camera2D


func _close_all_stalls() -> void:
	for node in get_tree().get_nodes_in_group("stall"):
		if node.get("is_open"):
			node.call("close")


func _scene_for_id(target_scene: String) -> PackedScene:
	return _scene_route_for_id(target_scene).get("scene", HOME_SCENE) as PackedScene


func _scene_route_for_id(target_scene: String) -> Dictionary:
	return SCENE_ROUTES.get(target_scene, SCENE_ROUTES[PrototypeConstants.SCENE_HOME])


func _scene_route_ids_for_test() -> Array:
	return SCENE_ROUTES.keys()


func _scene_entry_for_test(target_scene: String) -> String:
	return str(_scene_route_for_id(target_scene).get("entry", SCENE_ENTRY_DEFAULT))


func _remaining_apples() -> int:
	var total := Inventory.get_count(PrototypeConstants.ITEM_APPLE)
	if current_world != null:
		for node in get_tree().get_nodes_in_group("stall"):
			if node.get("is_open"):
				total += int(node.get("stock"))
	return total


func _initialize_game_state() -> void:
	var pending_load := SaveManager.consume_pending_load()
	_startup_spawn_id = "default"
	GameState.reset_game()
	if pending_load.is_empty():
		return
	GameState.apply_save_data(pending_load.get("game_state", {}))
	Inventory.apply_save_data(pending_load.get("inventory", {}))
	Hotbar.apply_save_data(pending_load.get("hotbar", {}))
	_startup_spawn_id = "bed_spawn" if GameState.current_scene == PrototypeConstants.SCENE_HOUSE else "default"


func _hotbar_index_from_event(event: InputEvent) -> int:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return -1
	if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
		return int(key_event.keycode - KEY_1)
	if key_event.keycode >= KEY_KP_1 and key_event.keycode <= KEY_KP_9:
		return int(key_event.keycode - KEY_KP_1)
	return -1


func _create_stall_action_panel() -> void:
	stall_action_panel = StallActionPanelScript.new()
	stall_action_panel.name = "StallActionPanel"
	add_child(stall_action_panel)
	stall_action_panel.stall_selected.connect(_on_stall_action_stall_selected)
	stall_action_panel.begging_selected.connect(_on_stall_action_begging_selected)


func _create_lottery_panel() -> void:
	lottery_panel = LotteryPanelScript.new()
	lottery_panel.name = "LotteryPanel"
	add_child(lottery_panel)


func _create_sleep_transition_overlay() -> void:
	_sleep_transition_layer = CanvasLayer.new()
	_sleep_transition_layer.name = "SleepTransitionLayer"
	_sleep_transition_layer.layer = 100
	add_child(_sleep_transition_layer)

	_sleep_transition_rect = ColorRect.new()
	_sleep_transition_rect.name = "SleepFade"
	_sleep_transition_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_sleep_transition_rect.visible = false
	_sleep_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sleep_transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sleep_transition_layer.add_child(_sleep_transition_rect)
