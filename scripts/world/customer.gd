extends CharacterBody2D

const SPEED := 55.0
const STUDENT_TEXTURE := preload("res://assets/generated/prototype_v1_32/characters/customer_student_48x64.png")
const WORKER_TEXTURE := preload("res://assets/generated/prototype_v1_32/characters/customer_worker_48x64.png")

@export var customer_type := PrototypeConstants.CUSTOMER_STUDENT

var target_stall: Node = null
var state := "walking"
var exit_position := Vector2.ZERO
var _started_at := 0.0

@onready var visual: Sprite2D = $Visual


func setup(next_type: String, stall: Node, start_position: Vector2, leave_position: Vector2) -> void:
	customer_type = next_type
	target_stall = stall
	global_position = start_position
	exit_position = leave_position
	_apply_customer_texture()


func _ready() -> void:
	_started_at = Time.get_ticks_msec() / 1000.0
	_apply_customer_texture()


func _physics_process(_delta: float) -> void:
	if target_stall != null and target_stall.get("is_open") and state == "walking":
		var stall_node := target_stall as Node2D
		var target: Vector2 = stall_node.global_position + Vector2(0, 58)
		_move_towards(target)
		if global_position.distance_to(target) < 8.0:
			state = "asking"
			_attempt_trade()
	else:
		state = "leaving"
		_move_towards(exit_position)
		if global_position.distance_to(exit_position) < 10.0 or (Time.get_ticks_msec() / 1000.0) - _started_at > 18.0:
			queue_free()


func _move_towards(target: Vector2) -> void:
	var direction := global_position.direction_to(target)
	velocity = direction * SPEED
	if abs(direction.x) > 0.05:
		visual.flip_h = direction.x < 0.0
	move_and_slide()


func _attempt_trade() -> void:
	if target_stall == null:
		return
	var decision: Dictionary = target_stall.call("sell_one", customer_type)
	state = "buying" if bool(decision["bought"]) else "rejecting"
	await get_tree().create_timer(0.45).timeout
	state = "leaving"


func _apply_customer_texture() -> void:
	if not is_node_ready():
		return
	visual.texture = WORKER_TEXTURE if customer_type == PrototypeConstants.CUSTOMER_WORKER else STUDENT_TEXTURE
