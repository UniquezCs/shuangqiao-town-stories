extends CharacterBody2D

const TEXTURE := preload("res://assets/generated/prototype_v1_32/characters/customer_worker_48x64.png")

var route_points: Array[Vector2] = []
var route_index := 0
var state := "patrolling"
var _has_penalized := false
var _last_penalty_text := ""
var _target_player: Node2D = null
var _target_stall: Node = null
var _violation_confirmed := false

@onready var visual: Sprite2D = $Visual
@onready var detection_area: Area2D = $DetectionArea
@onready var catch_area: Area2D = get_node_or_null("CatchArea") as Area2D


func _ready() -> void:
	visual.texture = TEXTURE
	detection_area.area_entered.connect(_on_detection_area_entered)
	if catch_area != null:
		catch_area.body_entered.connect(_on_catch_area_body_entered)
	if route_points.is_empty():
		route_points = [
			global_position + Vector2(220, 0),
			global_position + Vector2(-220, 0),
		]


func setup(start_position: Vector2, patrol_points: Array[Vector2]) -> void:
	global_position = start_position
	route_points = patrol_points.duplicate()
	route_index = 0


func _physics_process(_delta: float) -> void:
	if state == "chasing":
		_chase_player()
		return
	_patrol()


func _patrol() -> void:
	if route_points.is_empty():
		return
	var target := route_points[min(route_index, route_points.size() - 1)]
	_move_towards(target, PrototypeConstants.CHENGGUAN_PATROL_SPEED)
	if global_position.distance_to(target) < 10.0:
		route_index += 1
	if route_index >= route_points.size():
		queue_free()


func _chase_player() -> void:
	if _target_player == null or not is_instance_valid(_target_player):
		state = "patrolling"
		return
	_move_towards(_target_player.global_position, PrototypeConstants.CHENGGUAN_CHASE_SPEED)


func _move_towards(target: Vector2, speed: float) -> void:
	var direction := global_position.direction_to(target)
	velocity = direction * speed
	if abs(direction.x) > 0.05:
		visual.flip_h = direction.x < 0.0
	move_and_slide()


func _on_detection_area_entered(area: Area2D) -> void:
	if _has_penalized or not area.is_in_group("open_stall_inspection_target"):
		return
	var stall := area.get_parent()
	if stall == null or not bool(stall.get("is_open")):
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	_target_stall = stall
	_target_player = player
	_violation_confirmed = true
	state = "chasing"
	SignalBus.sale_feedback.emit("城管发现摊位，快跑！", global_position)
	_show_penalty_label("站住！")


func _on_catch_area_body_entered(body: Node) -> void:
	if state != "chasing" or _has_penalized or not body.is_in_group("player"):
		return
	_penalize_if_stall_is_open()


func _penalize_if_stall_is_open() -> void:
	if not _violation_confirmed:
		state = "patrolling"
		_target_player = null
		_target_stall = null
		return
	_has_penalized = true
	var fine := GameState.record_chengguan_penalty(PrototypeConstants.CHENGGUAN_FINE)
	if _target_stall != null and is_instance_valid(_target_stall) and bool(_target_stall.get("is_open")):
		_target_stall.call("close")
	_last_penalty_text = "被城管抓住，罚款 %d 元" % fine
	SignalBus.sale_feedback.emit(_last_penalty_text, global_position)
	_show_penalty_label(_last_penalty_text)
	state = "patrolling"
	_target_player = null
	_target_stall = null
	_violation_confirmed = false


func _show_penalty_label(text: String) -> void:
	var label := Label.new()
	label.name = "PenaltyLabel"
	label.text = text
	label.position = Vector2(-54, -86)
	label.add_theme_font_size_override("font_size", 14)
	add_child(label)
	var timer := Timer.new()
	timer.name = "PenaltyLabelTimer"
	timer.one_shot = true
	timer.wait_time = 2.0
	timer.timeout.connect(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
		timer.queue_free()
	)
	add_child(timer)
	timer.start()
