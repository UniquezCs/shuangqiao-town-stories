extends Node

const CUSTOMER_SCENE := preload("res://scenes/customer.tscn")
const CustomerSchedule := preload("res://scripts/world/customer_schedule.gd")

@export var spot_id := PrototypeConstants.SPOT_SCHOOL
@export var customer_type := PrototypeConstants.CUSTOMER_STUDENT
@export var spawn_offset := Vector2(-260, 0)
@export var exit_offset := Vector2(260, 0)
@export var route_anchor_offset := Vector2(0, 42)

@onready var timer: Timer = $Timer
@onready var stall_spot: Node2D = get_parent() as Node2D

var _spawn_plan: Array = []
var _spawn_index := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_spawn_plan = CustomerSchedule.build_daily_spawn_plan(customer_type, _rng)
	SignalBus.game_time_changed.connect(_on_game_time_changed)
	_on_game_time_changed(GameState.current_game_minute, GameState.format_game_time(GameState.current_game_minute))


func _on_game_time_changed(total_minutes: int, _clock_text: String) -> void:
	while _spawn_index < _spawn_plan.size() and int(_spawn_plan[_spawn_index]["minute"]) <= total_minutes:
		_spawn_customer(str(_spawn_plan[_spawn_index]["mode"]))
		_spawn_index += 1


func _spawn_customer(route_mode: String) -> void:
	if route_mode == CustomerSchedule.ROUTE_NONE:
		return
	var route := _route_for_mode(route_mode)
	var customer := CUSTOMER_SCENE.instantiate()
	get_tree().current_scene.add_child(customer)
	customer.call("setup", customer_type, stall_spot, route["start"], route["end"])


func _route_for_mode(route_mode: String) -> Dictionary:
	var residence := _residential_position()
	var destination := stall_spot.global_position + route_anchor_offset
	if route_mode == CustomerSchedule.ROUTE_HOME_TO_DESTINATION:
		return {"start": residence, "end": destination}
	return {"start": destination, "end": residence}


func _residential_position() -> Vector2:
	var world := stall_spot.get_parent()
	if world != null:
		var marker := world.get_node_or_null("ResidentialArea/ResidentSpawn") as Marker2D
		if marker != null:
			return marker.global_position
	return stall_spot.global_position + spawn_offset
