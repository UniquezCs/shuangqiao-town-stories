extends CharacterBody2D

const SPEED := 55.0
const DEMAND_THRESHOLD := 0.45
const STUDENT_TEXTURE := preload("res://assets/generated/prototype_v1_32/characters/customer_student_48x64.png")
const WORKER_TEXTURE := preload("res://assets/generated/prototype_v1_32/characters/customer_worker_48x64.png")
const APPLE_ICON_TEXTURE := preload("res://assets/generated/prototype_v1_32/props/apple_32.png")
const PurchaseInteractionScript := preload("res://scripts/world/customer_purchase_interaction.gd")

@export var customer_type := PrototypeConstants.CUSTOMER_STUDENT

var target_stall: Node = null
var state := "walking"
var exit_position := Vector2.ZERO
var _started_at := 0.0
var _customer_profile := {}
var _influence_stall: Node = null
var _route_points: Array[Vector2] = []
var _route_index := 0
var _tree_entered_position: Vector2
var _purchase_stall: Node = null
var _purchase_deadline_msec := 0
var _rng := RandomNumberGenerator.new()

@onready var visual: Sprite2D = $Visual


func setup(next_type: String, stall: Node, start_position: Vector2, leave_position: Vector2, route_points: Array = []) -> void:
	customer_type = next_type
	target_stall = stall
	global_position = start_position
	exit_position = leave_position
	_route_points.clear()
	for point in route_points:
		_route_points.append(point as Vector2)
	_route_points.append(exit_position)
	_route_index = 0
	_build_customer_profile()
	_apply_customer_texture()


func _enter_tree() -> void:
	_tree_entered_position = global_position


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
			_begin_purchase_request(active_stall)
	elif state == "walking":
		_walk_to_exit()
	elif state == "leaving":
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


func _begin_purchase_request(active_stall: Node) -> void:
	if active_stall == null or state == "waiting_for_player":
		return
	if active_stall.has_method("can_sell_to"):
		var preview: Dictionary = active_stall.call("can_sell_to", customer_type, _customer_profile)
		if not bool(preview.get("bought", false)):
			_reject_without_trade(str(preview.get("reason", "顾客离开")))
			return

	state = "waiting_for_player"
	velocity = Vector2.ZERO
	_purchase_stall = active_stall
	_create_purchase_interaction()
	_create_purchase_countdown()
	_start_purchase_timer()


func confirm_purchase(_player: Node = null) -> void:
	if state != "waiting_for_player" or _purchase_stall == null or not is_instance_valid(_purchase_stall):
		return
	var stall := _purchase_stall
	_clear_purchase_request()
	_attempt_trade(stall)


func _reject_without_trade(reason: String) -> void:
	GameState.record_rejection()
	GameState.record_customer_served()
	SignalBus.sale_feedback.emit(reason, global_position)
	SignalBus.customer_decision.emit(customer_type, false, reason)
	state = "rejecting"
	await get_tree().create_timer(0.45).timeout
	state = "leaving"


func _create_purchase_interaction() -> void:
	if get_node_or_null("PurchaseInteraction") != null:
		return
	var interaction := Area2D.new()
	interaction.name = "PurchaseInteraction"
	interaction.collision_layer = 2
	interaction.collision_mask = 0
	interaction.monitoring = false
	interaction.monitorable = true
	interaction.set_script(PurchaseInteractionScript)
	interaction.set("customer", self)

	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = 32.0
	shape_node.shape = circle
	interaction.add_child(shape_node)
	add_child(interaction)


func _create_purchase_countdown() -> void:
	if get_node_or_null("PurchaseCountdown") != null:
		return
	var indicator := Node2D.new()
	indicator.name = "PurchaseCountdown"
	indicator.position = Vector2(0, -72)
	add_child(indicator)

	var icon := Sprite2D.new()
	icon.name = "AppleIcon"
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = APPLE_ICON_TEXTURE
	icon.scale = Vector2(0.75, 0.75)
	indicator.add_child(icon)

	var label := Label.new()
	label.name = "SecondsLabel"
	label.position = Vector2(12, -12)
	label.add_theme_font_size_override("font_size", 14)
	indicator.add_child(label)


func _start_purchase_timer() -> void:
	var wait_seconds := _rng.randf_range(
		PrototypeConstants.CUSTOMER_PURCHASE_WAIT_MIN_SECONDS,
		PrototypeConstants.CUSTOMER_PURCHASE_WAIT_MAX_SECONDS
	)
	_purchase_deadline_msec = Time.get_ticks_msec() + int(wait_seconds * 1000.0)

	var timer := Timer.new()
	timer.name = "PurchaseTimer"
	timer.one_shot = true
	timer.wait_time = wait_seconds
	timer.timeout.connect(_on_purchase_timeout)
	add_child(timer)
	timer.start()

	var tick_timer := Timer.new()
	tick_timer.name = "PurchaseTickTimer"
	tick_timer.wait_time = 1.0
	tick_timer.timeout.connect(_update_purchase_countdown)
	add_child(tick_timer)
	tick_timer.start()
	_update_purchase_countdown()


func _update_purchase_countdown() -> void:
	var label := get_node_or_null("PurchaseCountdown/SecondsLabel") as Label
	if label == null:
		return
	var remaining: int = max(0, int(ceil(float(_purchase_deadline_msec - Time.get_ticks_msec()) / 1000.0)))
	label.text = str(remaining)


func _on_purchase_timeout() -> void:
	if state != "waiting_for_player":
		return
	_clear_purchase_request()
	GameState.record_rejection()
	GameState.record_customer_served()
	SignalBus.sale_feedback.emit("顾客等不及走了", global_position)
	state = "leaving"


func _clear_purchase_request() -> void:
	_purchase_stall = null
	for node_name in ["PurchaseInteraction", "PurchaseCountdown", "PurchaseTimer", "PurchaseTickTimer"]:
		var node := get_node_or_null(node_name)
		if node != null:
			remove_child(node)
			node.queue_free()


func _apply_customer_texture() -> void:
	if not is_node_ready():
		return
	visual.texture = WORKER_TEXTURE if customer_type == PrototypeConstants.CUSTOMER_WORKER else STUDENT_TEXTURE


func _walk_to_exit() -> void:
	if _route_points.is_empty():
		_route_points.append(exit_position)
	var target := _route_points[min(_route_index, _route_points.size() - 1)]
	_move_towards(target)
	if global_position.distance_to(target) < 10.0:
		_route_index += 1
	if _route_index >= _route_points.size() or (Time.get_ticks_msec() / 1000.0) - _started_at > 18.0:
		queue_free()


func _should_visit_stall(active_stall: Node) -> bool:
	if active_stall == null or not is_instance_valid(active_stall):
		return false
	if not bool(active_stall.get("is_open")) or int(active_stall.get("stock")) <= 0:
		return false
	return _has_demand_for(str(active_stall.get("current_item_id")))


func _active_stall() -> Node:
	if _influence_stall != null and is_instance_valid(_influence_stall) and bool(_influence_stall.get("is_open")):
		return _influence_stall
	return null


func enter_stall_influence(stall: Node) -> void:
	if target_stall == null or not is_instance_valid(target_stall):
		return
	var active_stall: Node = null
	if target_stall.has_method("get_active_stall"):
		active_stall = target_stall.call("get_active_stall")
	elif bool(target_stall.get("is_open")):
		active_stall = target_stall
	if stall == active_stall:
		_influence_stall = stall


func exit_stall_influence(stall: Node) -> void:
	if stall == _influence_stall and state == "walking":
		_influence_stall = null


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
			"cabbage": _rng.randf_range(0.2, 0.85),
			"cucumber": _rng.randf_range(0.2, 0.85),
			"tomato": _rng.randf_range(0.25, 0.9),
			"pear": _rng.randf_range(0.25, 0.9),
			"potato": _rng.randf_range(0.2, 0.85),
		},
	}
