extends CharacterBody2D

const SPRITE_FRAMES := preload("res://assets/generated/sprites/characters/chengguan_walk_spriteframes_48x64.tres")
const STUCK_SECONDS := 0.75
const STUCK_MIN_PROGRESS := 0.2
const STUCK_TARGET_RESET_DISTANCE := 4.0
const DETOUR_DISTANCE := 96.0
const DETOUR_FORWARD_DISTANCE := 32.0

var route_points: Array[Vector2] = []
var route_index := 0
var state := "patrolling"
var facing := "down"
var _return_route_points: Array[Vector2] = []
var _resume_route_state := "patrolling"
var _has_penalized := false
var _last_penalty_text := ""
var _target_player: Node2D = null
var _target_stall: Node = null
var _violation_confirmed := false
var _tree_entered_position: Vector2
var _has_stuck_target := false
var _stuck_target := Vector2.ZERO
var _stuck_seconds := 0.0
var _last_slide_normal := Vector2.ZERO
var _detour_serial := 0
var _has_chase_detour := false
var _chase_detour := Vector2.ZERO

@onready var visual: AnimatedSprite2D = $Visual
@onready var detection_area: Area2D = $DetectionArea
@onready var catch_area: Area2D = get_node_or_null("CatchArea") as Area2D


func _ready() -> void:
	visual.sprite_frames = SPRITE_FRAMES
	_pause_current_animation()
	detection_area.area_entered.connect(_on_detection_area_entered)
	if catch_area != null:
		catch_area.body_entered.connect(_on_catch_area_body_entered)
	if route_points.is_empty():
		route_points = [
			global_position + Vector2(220, 0),
			global_position + Vector2(-220, 0),
		]


func setup(start_position: Vector2, patrol_points: Array[Vector2], return_points: Array[Vector2] = []) -> void:
	global_position = start_position
	route_points = patrol_points.duplicate()
	_return_route_points = return_points.duplicate()
	route_index = 0
	state = "patrolling"


func _enter_tree() -> void:
	_tree_entered_position = global_position


func _physics_process(delta: float) -> void:
	if state == "chasing":
		_chase_player(delta)
		return
	_patrol(delta)


func _patrol(delta: float) -> void:
	if route_points.is_empty():
		return
	var target := route_points[min(route_index, route_points.size() - 1)]
	if _move_towards(target, PrototypeConstants.CHENGGUAN_PATROL_SPEED, delta):
		_insert_detour_before_current_route_target(target)
		_reset_stuck_tracking()
		return
	if global_position.distance_to(target) < 10.0:
		route_index += 1
		_reset_stuck_tracking()
	if route_index >= route_points.size():
		if state == "patrolling" and not _return_route_points.is_empty():
			_begin_return_route()
			return
		queue_free()


func _begin_return_route() -> void:
	route_points = _return_route_points.duplicate()
	_return_route_points.clear()
	route_index = 0
	state = "returning"
	_reset_stuck_tracking()


func _chase_player(delta: float) -> void:
	if _target_player == null or not is_instance_valid(_target_player):
		state = _resume_route_state
		_has_chase_detour = false
		return
	var target := _chase_detour if _has_chase_detour else _target_player.global_position
	if _move_towards(target, PrototypeConstants.CHENGGUAN_CHASE_SPEED, delta):
		_chase_detour = _detour_point_for_target(_target_player.global_position)
		_has_chase_detour = true
		_reset_stuck_tracking()
		return
	if _has_chase_detour and global_position.distance_to(_chase_detour) < 10.0:
		_has_chase_detour = false
		_reset_stuck_tracking()


func _move_towards(target: Vector2, speed: float, delta := 0.0) -> bool:
	var direction := global_position.direction_to(target)
	velocity = direction * speed
	_play_walk_animation(direction)
	var before_position := global_position
	move_and_slide()
	_remember_slide_normal()
	return _update_stuck_tracking(target, before_position, delta)


func _insert_detour_before_current_route_target(target: Vector2) -> void:
	var insert_index := clampi(route_index, 0, route_points.size())
	var replacement_points := _reroute_points_for_target(target)
	for index in range(replacement_points.size() - 1, -1, -1):
		route_points.insert(insert_index, replacement_points[index])


func _reroute_points_for_target(target: Vector2) -> Array[Vector2]:
	var navigator := _road_navigator()
	if navigator != null:
		var road_path: Array = []
		if navigator.has_method("find_randomized_path"):
			road_path = navigator.call("find_randomized_path", global_position, target)
		elif navigator.has_method("find_path"):
			road_path = navigator.call("find_path", global_position, target)
		var normalized_path := _normalized_reroute_points(road_path, target)
		if not normalized_path.is_empty():
			return normalized_path
	return [_detour_point_for_target(target)]


func _normalized_reroute_points(points: Array, target: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point in points:
		var typed_point := point as Vector2
		if global_position.distance_to(typed_point) <= 10.0:
			continue
		if typed_point.distance_to(target) <= 10.0:
			continue
		result.append(typed_point)
	return result


func _road_navigator() -> Node:
	var node: Node = self
	while node != null:
		var navigator := node.get_node_or_null("RoadNavigator")
		if navigator != null:
			return navigator
		node = node.get_parent()
	for navigator in get_tree().get_nodes_in_group("road_navigator"):
		if navigator is Node and is_instance_valid(navigator):
			return navigator
	return null


func _detour_point_for_target(target: Vector2) -> Vector2:
	var normal := _last_slide_normal
	if normal.length() <= 0.0:
		normal = -global_position.direction_to(target)
	var tangent := Vector2(-normal.y, normal.x)
	if tangent.length() <= 0.0:
		tangent = Vector2.UP
	tangent = tangent.normalized()
	var side := 1.0 if _detour_serial % 2 == 0 else -1.0
	_detour_serial += 1
	var forward := global_position.direction_to(target) * DETOUR_FORWARD_DISTANCE
	return global_position + tangent * DETOUR_DISTANCE * side + forward


func _update_stuck_tracking(target: Vector2, before_position: Vector2, delta: float) -> bool:
	if delta <= 0.0:
		return false
	if not _has_stuck_target or _stuck_target.distance_to(target) > STUCK_TARGET_RESET_DISTANCE:
		_has_stuck_target = true
		_stuck_target = target
		_stuck_seconds = 0.0
	var moved_distance := before_position.distance_to(global_position)
	if get_slide_collision_count() > 0 and moved_distance <= STUCK_MIN_PROGRESS:
		_stuck_seconds += delta
	else:
		_stuck_seconds = 0.0
	return _stuck_seconds >= STUCK_SECONDS


func _reset_stuck_tracking() -> void:
	_has_stuck_target = false
	_stuck_seconds = 0.0


func _remember_slide_normal() -> void:
	_last_slide_normal = Vector2.ZERO
	if get_slide_collision_count() <= 0:
		return
	var collision := get_slide_collision(0)
	if collision != null:
		_last_slide_normal = collision.get_normal()


func _play_walk_animation(direction: Vector2) -> void:
	if direction.length() <= 0.0:
		_pause_current_animation()
		return
	if abs(direction.x) > abs(direction.y):
		facing = "right" if direction.x > 0.0 else "left"
	else:
		facing = "down" if direction.y > 0.0 else "up"
	var animation := "walk_%s" % facing
	if visual.animation != animation:
		visual.play(animation)
	elif not visual.is_playing():
		visual.play()


func _pause_current_animation() -> void:
	var animation := "walk_%s" % facing
	if visual.animation != animation:
		visual.play(animation)
	visual.frame = 0
	visual.pause()


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
	_resume_route_state = state
	state = "chasing"
	SignalBus.sale_feedback.emit("城管发现摊位，快跑！", global_position)
	_show_penalty_label("站住！")


func _on_catch_area_body_entered(body: Node) -> void:
	if state != "chasing" or _has_penalized or not body.is_in_group("player"):
		return
	_penalize_if_stall_is_open()


func _penalize_if_stall_is_open() -> void:
	if not _violation_confirmed:
		state = _resume_route_state
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
	state = _resume_route_state
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
