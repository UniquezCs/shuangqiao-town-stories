extends Area2D

const BeggingSessionScript := preload("res://scripts/world/begging_session.gd")

@export var spot_id := PrototypeConstants.SPOT_SCHOOL
@export var label := "学校门口"
@export var can_open_stall := true
@export var interaction_size := Vector2(0, 0)
@export var interaction_offset := Vector2.ZERO

var _last_interacting_player: Node2D = null
var _static_body_offset_from_stall := Vector2.ZERO
var _begging_session: Node2D = null

@onready var stall: Node2D = $Stall
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var static_body: StaticBody2D = get_node_or_null("StaticBody2D") as StaticBody2D
@onready var static_body_shape: CollisionShape2D = get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D


func _ready() -> void:
	_static_body_offset_from_stall = _static_body_relative_to_stall_position()
	if can_open_stall:
		add_to_group("interactable")
	if stall != null:
		stall.visible = false
	_configure_interaction_shape()
	_set_static_body_enabled(false)
	if not SignalBus.stall_closed_node.is_connected(_on_stall_closed_node):
		SignalBus.stall_closed_node.connect(_on_stall_closed_node)


func get_prompt() -> String:
	if not can_open_stall:
		return ""
	if is_begging_active():
		return "长按结束乞讨"
	var typed_stall := stall as Node
	if typed_stall and typed_stall.get("is_open"):
		return "长按收摊"
	return "在%s经营" % label


func interact(player: Node) -> void:
	if not can_open_stall:
		return
	_last_interacting_player = player as Node2D
	if is_begging_active():
		var begging_player := player as Node2D
		var begging_feedback_position := begging_player.global_position if begging_player != null else global_position
		SignalBus.sale_feedback.emit("长按 E 1 秒结束乞讨", begging_feedback_position)
	elif stall.get("is_open"):
		var player_node := player as Node2D
		var feedback_position := player_node.global_position if player_node != null else global_position
		SignalBus.sale_feedback.emit("长按 E 3 秒收摊", feedback_position)
	else:
		SignalBus.stall_action_requested.emit(self)


func requires_hold_interact() -> bool:
	return can_open_stall and (bool(stall.get("is_open")) or is_begging_active())


func get_hold_interact_duration() -> float:
	if is_begging_active():
		return PrototypeConstants.BEGGING_STOP_HOLD_SECONDS
	return PrototypeConstants.STALL_CLOSE_HOLD_SECONDS


func begin_hold_interact(player: Node) -> void:
	var player_node := player as Node2D
	var feedback_position := player_node.global_position if player_node != null else global_position
	var text := "正在结束乞讨..." if is_begging_active() else "正在收摊..."
	SignalBus.sale_feedback.emit(text, feedback_position)


func cancel_hold_interact(player: Node) -> void:
	var player_node := player as Node2D
	var feedback_position := player_node.global_position if player_node != null else global_position
	var text := "继续乞讨" if is_begging_active() else "收摊取消"
	SignalBus.sale_feedback.emit(text, feedback_position)


func complete_hold_interact(player: Node) -> void:
	if is_begging_active():
		stop_begging(player)
		return
	if bool(stall.get("is_open")):
		var closed := bool(stall.call("close"))
		if closed:
			_set_static_body_enabled(false)


func open_stall(price: int) -> void:
	var opened := bool(stall.call("open", spot_id, price, _last_interacting_player))
	if opened:
		_configure_static_body_for_open_stall()


func open_stall_with_slots(prepared_slots: Array) -> bool:
	var opened := bool(stall.call("open_with_slots", spot_id, prepared_slots, _last_interacting_player))
	if opened:
		_configure_static_body_for_open_stall()
	return opened


func get_active_stall() -> Node:
	if stall.get("is_open"):
		return stall
	return null


func start_begging(player: Node) -> bool:
	if not can_open_stall or bool(stall.get("is_open")) or is_begging_active():
		return false
	_last_interacting_player = player as Node2D
	_begging_session = Node2D.new()
	_begging_session.name = "BeggingSession"
	_begging_session.set_script(BeggingSessionScript)
	add_child(_begging_session)
	_begging_session.call("start", spot_id, _last_interacting_player)
	if _begging_session.has_signal("ended"):
		_begging_session.connect("ended", _on_begging_session_ended)
	SignalBus.interaction_prompt_changed.emit(get_prompt())
	return true


func stop_begging(player: Node = null) -> void:
	if not is_begging_active():
		return
	var player_node := player as Node2D
	var feedback_position := player_node.global_position if player_node != null else global_position
	SignalBus.sale_feedback.emit("结束乞讨", feedback_position)
	_begging_session.call("stop")
	_begging_session = null
	SignalBus.interaction_prompt_changed.emit(get_prompt())


func is_begging_active() -> bool:
	return _begging_session != null and is_instance_valid(_begging_session) and _begging_session.get("is_active") == true


func _configure_interaction_shape() -> void:
	if collision_shape == null:
		return
	collision_shape.position = interaction_offset
	var rectangle := RectangleShape2D.new()
	collision_shape.shape = rectangle
	rectangle.size = interaction_size


func _static_body_relative_to_stall_position() -> Vector2:
	if stall == null or static_body == null or static_body_shape == null:
		return Vector2.ZERO
	return static_body.position + static_body_shape.position - stall.position


func _configure_static_body_for_open_stall() -> void:
	if static_body == null or static_body_shape == null:
		return
	static_body.position = stall.position
	static_body_shape.position = _static_body_offset_from_stall
	_set_static_body_enabled(true)


func _set_static_body_enabled(enabled: bool) -> void:
	if static_body_shape == null:
		return
	static_body_shape.disabled = not enabled


func _on_stall_closed_node(closed_stall: Node) -> void:
	if closed_stall == stall:
		_set_static_body_enabled(false)


func _on_begging_session_ended() -> void:
	_begging_session = null
