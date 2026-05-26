extends CharacterBody2D

const SPEED := 55.0
const DEMAND_THRESHOLD := 0.45
const STUDENT_TEXTURE := preload("res://assets/generated/prototype_v1_32/characters/customer_student_48x64.png")
const WORKER_TEXTURE := preload("res://assets/generated/prototype_v1_32/characters/customer_worker_48x64.png")

@export var customer_type := PrototypeConstants.CUSTOMER_STUDENT

var target_stall: Node = null
var state := "walking"
var exit_position := Vector2.ZERO
var _started_at := 0.0
var _customer_profile := {}
var _rng := RandomNumberGenerator.new()

@onready var visual: Sprite2D = $Visual


func setup(next_type: String, stall: Node, start_position: Vector2, leave_position: Vector2) -> void:
	customer_type = next_type
	target_stall = stall
	global_position = start_position
	exit_position = leave_position
	_build_customer_profile()
	_apply_customer_texture()


func _ready() -> void:
	_started_at = Time.get_ticks_msec() / 1000.0
	_apply_customer_texture()


func _physics_process(_delta: float) -> void:
	var active_stall := _active_stall()
	if state == "walking" and _should_visit_stall(active_stall):
		var stall_node := active_stall as Node2D
		var target: Vector2 = stall_node.global_position + Vector2(0, 58)
		_move_towards(target)
		if global_position.distance_to(target) < 8.0:
			state = "asking"
			_attempt_trade(active_stall)
	elif state == "walking" or state == "leaving":
		state = "leaving"
		_walk_to_exit()
	else:
		velocity = Vector2.ZERO
		move_and_slide()


func _move_towards(target: Vector2) -> void:
	var direction := global_position.direction_to(target)
	velocity = direction * SPEED
	if abs(direction.x) > 0.05:
		visual.flip_h = direction.x < 0.0
	move_and_slide()


func _attempt_trade(active_stall: Node) -> void:
	if active_stall == null:
		return
	var decision: Dictionary = active_stall.call("sell_one", customer_type, _customer_profile)
	state = "buying" if bool(decision["bought"]) else "rejecting"
	await get_tree().create_timer(0.45).timeout
	state = "leaving"


func _apply_customer_texture() -> void:
	if not is_node_ready():
		return
	visual.texture = WORKER_TEXTURE if customer_type == PrototypeConstants.CUSTOMER_WORKER else STUDENT_TEXTURE


func _walk_to_exit() -> void:
	_move_towards(exit_position)
	if global_position.distance_to(exit_position) < 10.0 or (Time.get_ticks_msec() / 1000.0) - _started_at > 18.0:
		queue_free()


func _should_visit_stall(active_stall: Node) -> bool:
	if active_stall == null or not is_instance_valid(active_stall):
		return false
	if not bool(active_stall.get("is_open")) or int(active_stall.get("stock")) <= 0:
		return false
	return _has_demand_for(PrototypeConstants.ITEM_APPLE)


func _active_stall() -> Node:
	if target_stall == null or not is_instance_valid(target_stall):
		return null
	if target_stall.has_method("get_active_stall"):
		return target_stall.call("get_active_stall")
	if bool(target_stall.get("is_open")):
		return target_stall
	return null


func _has_demand_for(item_id: String) -> bool:
	var preferences: Dictionary = _customer_profile.get("preferences", {})
	return float(preferences.get(item_id, 0.0)) >= DEMAND_THRESHOLD


func _build_customer_profile() -> void:
	_rng.randomize()
	var budget := _rng.randi_range(1, 3)
	var apple_preference := _rng.randf_range(0.25, 0.95)
	if customer_type == PrototypeConstants.CUSTOMER_WORKER:
		budget = _rng.randi_range(2, 5)
		apple_preference = _rng.randf_range(0.2, 0.9)
	_customer_profile = {
		"budget": budget,
		"preferences": {
			PrototypeConstants.ITEM_APPLE: apple_preference,
		},
	}
