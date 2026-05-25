extends Node

@export var spot_id := PrototypeConstants.SPOT_SCHOOL
@export var customer_type := PrototypeConstants.CUSTOMER_STUDENT
@export var spawn_offset := Vector2(-260, 0)
@export var exit_offset := Vector2(260, 0)

@onready var timer: Timer = $Timer
@onready var stall_spot: Node = get_parent()


func _ready() -> void:
	timer.timeout.connect(_on_timer_timeout)
	SignalBus.time_window_changed.connect(_on_time_window_changed)
	_on_time_window_changed(GameState.current_time_window)


func _on_time_window_changed(_window_id: String) -> void:
	timer.wait_time = _wait_time_for_window()
	if not timer.is_stopped():
		timer.stop()
	timer.start(timer.wait_time)


func _on_timer_timeout() -> void:
	var stall: Node = stall_spot.call("get_active_stall")
	if stall != null:
		var customer := preload("res://scenes/customer.tscn").instantiate()
		get_tree().current_scene.add_child(customer)
		customer.call("setup", customer_type, stall, stall_spot.global_position + spawn_offset, stall_spot.global_position + exit_offset)
	timer.wait_time = _wait_time_for_window()
	timer.start(timer.wait_time)


func _wait_time_for_window() -> float:
	var window: String = str(GameState.current_time_window)
	if spot_id == PrototypeConstants.SPOT_SCHOOL and window == PrototypeConstants.WINDOW_SCHOOL:
		return 2.2
	if spot_id == PrototypeConstants.SPOT_FACTORY and window == PrototypeConstants.WINDOW_FACTORY:
		return 2.8
	if window == PrototypeConstants.WINDOW_MORNING:
		return 6.0
	return 7.5
