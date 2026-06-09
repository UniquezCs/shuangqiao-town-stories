extends CharacterBody2D

const SPEED := 55.0
const DEMAND_THRESHOLD := 0.56
const ROUTE_TIMEOUT_PADDING_SECONDS := 10.0
const STUCK_SECONDS := 0.75
const STUCK_MIN_PROGRESS := 0.2
const STUCK_TARGET_RESET_DISTANCE := 4.0
const DETOUR_DISTANCE := 96.0
const DETOUR_FORWARD_DISTANCE := 32.0
const STUDENT_FRAMES := preload("res://assets/generated/sprites/characters/student_walk_spriteframes_48x64.tres")
const WORKER_FRAMES := preload("res://assets/generated/sprites/characters/worker_walk_spriteframes_48x64.tres")
const YOUTH_FEMALE_FRAMES := preload("res://assets/generated/sprites/characters/youth_female_walk_spriteframes_48x64.tres")
const ELDER_MALE_FRAMES := preload("res://assets/generated/sprites/characters/elder_male_walk_spriteframes_48x64.tres")
const FEMALE_ELDER_FRAMES := preload("res://assets/generated/sprites/characters/female_elder_walk_spriteframes_48x64.tres")
const FEMALE_MIDDLE_FRAMES := preload("res://assets/generated/sprites/characters/female_middle_walk_spriteframes_48x64.tres")
const PurchaseInteractionScript := preload("res://scripts/world/customer_purchase_interaction.gd")
const PurchaseCountdownScript := preload("res://scripts/ui/circular_countdown_indicator.gd")
const CustomerDialogueLines := preload("res://scripts/world/customer_dialogue_lines.gd")
const CustomerDialogueFeedback := preload("res://scripts/world/customer_dialogue_feedback.gd")
const GameplayDebugLog := preload("res://scripts/debug/gameplay_debug_log.gd")

@export var customer_type := PrototypeConstants.CUSTOMER_STUDENT
@export var visual_variant := ""
@export var age_group := ""
@export var gender := ""

var target_stall: Node = null
var state := "walking"
var exit_position := Vector2.ZERO
var facing := "down"
var _started_at := 0.0
var _customer_profile := {}
var _influence_stall: Node = null
var _route_points: Array[Vector2] = []
var _route_index := 0
var _route_timeout_seconds := 18.0
var _tree_entered_position: Vector2
var _setup_start_position := Vector2.ZERO
var _has_setup_start_position := false
var _purchase_stall: Node = null
var _purchase_preview: Dictionary = {}
var _purchase_deadline_msec := 0
var _rng := RandomNumberGenerator.new()
var _begging_session_ids := {}
var _visit_target_stall: Node = null
var _visit_target_position := Vector2.ZERO
var _has_stuck_target := false
var _stuck_target := Vector2.ZERO
var _stuck_seconds := 0.0
var _last_slide_normal := Vector2.ZERO
var _detour_serial := 0
var _dialogue_feedback: Node = null

@onready var visual: AnimatedSprite2D = $Visual


func setup(next_type: String, stall: Node, start_position: Vector2, leave_position: Vector2, route_points: Array = [], next_visual_variant := "", next_age_group := "", next_gender := "") -> void:
	customer_type = next_type
	visual_variant = next_visual_variant
	age_group = next_age_group
	gender = next_gender
	_apply_default_demographics()
	target_stall = stall
	_setup_start_position = start_position
	_has_setup_start_position = true
	global_position = start_position
	exit_position = leave_position
	_route_points.clear()
	for point in route_points:
		_route_points.append(point as Vector2)
	_route_points.append(exit_position)
	_route_index = 0
	_route_timeout_seconds = _calculate_route_timeout(start_position, _route_points)
	_build_customer_profile()
	_apply_customer_spriteframes()


func _enter_tree() -> void:
	if _has_setup_start_position:
		global_position = _setup_start_position
	_tree_entered_position = global_position


func _ready() -> void:
	_started_at = Time.get_ticks_msec() / 1000.0
	SignalBus.stall_closed_node.connect(_on_stall_closed_node)
	SignalBus.stall_inventory_changed.connect(_on_stall_inventory_changed)
	_apply_customer_spriteframes()
	_pause_current_animation()


func _physics_process(delta: float) -> void:
	var active_stall := _active_stall()
	if state == "walking" and _should_visit_stall(active_stall):
		var target := _visit_target_for_stall(active_stall)
		if _move_towards(target, delta):
			_abandon_stall_visit()
			return
		if global_position.distance_to(target) < 8.0:
			_begin_purchase_request(active_stall)
	elif state == "walking":
		_walk_to_exit(delta)
	elif state == "leaving":
		state = "leaving"
		_walk_to_exit(delta)
	else:
		_reset_stuck_tracking()
		velocity = Vector2.ZERO
		_pause_current_animation()
		move_and_slide()


func _move_towards(target: Vector2, delta := 0.0) -> bool:
	var direction := global_position.direction_to(target)
	velocity = direction * SPEED
	_play_walk_animation(direction)
	var before_position := global_position
	move_and_slide()
	_remember_slide_normal()
	return _update_stuck_tracking(target, before_position, delta)


func _attempt_trade(active_stall: Node) -> void:
	if active_stall == null:
		return
	var decision: Dictionary = active_stall.call("sell_one", customer_type, _customer_profile)
	state = "buying" if bool(decision["bought"]) else "rejecting"
	if bool(decision["bought"]):
		_show_customer_dialogue(CustomerDialogueLines.EVENT_PURCHASED, str(decision.get("item_id", _purchase_preview.get("item_id", ""))), int(decision.get("price", _purchase_preview.get("price", 0))), str(decision.get("reason", "")))
	else:
		_show_customer_dialogue(str(decision.get("dialogue_event", CustomerDialogueLines.EVENT_PRICE_REJECT)), str(decision.get("item_id", _purchase_preview.get("item_id", ""))), int(decision.get("price", _purchase_preview.get("price", 0))), str(decision.get("reason", "")))
	await get_tree().create_timer(0.45).timeout
	state = "leaving"


func _begin_purchase_request(active_stall: Node) -> void:
	if active_stall == null or state == "waiting_for_player":
		return
	if active_stall.has_method("can_sell_to"):
		var preview: Dictionary = active_stall.call("can_sell_to", customer_type, _customer_profile)
		if not bool(preview.get("bought", false)):
			GameplayDebugLog.log("customer", "reject_preview", {
				"customer_type": customer_type,
				"reason": str(preview.get("reason", "顾客离开")),
			})
			_reject_without_trade(str(preview.get("reason", "顾客离开")), preview)
			return
		_purchase_preview = preview.duplicate(true)
	else:
		_purchase_preview = {}

	state = "waiting_for_player"
	velocity = Vector2.ZERO
	_pause_current_animation()
	_purchase_stall = active_stall
	GameplayDebugLog.log("customer", "waiting_for_player", {
		"customer_type": customer_type,
		"item_id": str(_purchase_preview.get("item_id", "")),
		"price": int(_purchase_preview.get("price", 0)),
	})
	_show_customer_dialogue(CustomerDialogueLines.EVENT_WAITING, str(_purchase_preview.get("item_id", "")), int(_purchase_preview.get("price", 0)), str(_purchase_preview.get("reason", "")))
	_create_purchase_interaction()
	_create_purchase_countdown()
	_start_purchase_timer()


func confirm_purchase(_player: Node = null) -> void:
	if state != "waiting_for_player" or _purchase_stall == null or not is_instance_valid(_purchase_stall):
		return
	var stall := _purchase_stall
	_clear_purchase_request()
	_attempt_trade(stall)


func _reject_without_trade(reason: String, preview: Dictionary = {}) -> void:
	GameState.record_rejection()
	GameState.record_customer_served()
	SignalBus.sale_feedback.emit(reason, global_position)
	SignalBus.customer_decision.emit(customer_type, false, reason)
	_show_customer_dialogue(str(preview.get("dialogue_event", CustomerDialogueLines.EVENT_PRICE_REJECT)), str(preview.get("item_id", PrototypeConstants.ITEM_APPLE)), int(preview.get("price", 0)), reason)
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
	indicator.set_script(PurchaseCountdownScript)
	indicator.position = Vector2(0, -72)
	add_child(indicator)

	var item_id := str(_purchase_preview.get("item_id", PrototypeConstants.ITEM_APPLE))
	var icon_path := ConfigLoader.get_item_icon(item_id)
	var texture: Texture2D = null
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		texture = load(icon_path) as Texture2D
	indicator.call("set_icon_texture", texture)
	indicator.call("set_remaining_fraction", 1.0)


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
	tick_timer.wait_time = 0.1
	tick_timer.timeout.connect(_update_purchase_countdown)
	add_child(tick_timer)
	tick_timer.start()
	_update_purchase_countdown()


func _update_purchase_countdown() -> void:
	var indicator: Node = get_node_or_null("PurchaseCountdown")
	var timer := get_node_or_null("PurchaseTimer") as Timer
	if indicator == null or not indicator.has_method("set_remaining_fraction") or timer == null:
		return
	var remaining_seconds: float = maxf(0.0, float(_purchase_deadline_msec - Time.get_ticks_msec()) / 1000.0)
	var fraction: float = 0.0 if timer.wait_time <= 0.0 else remaining_seconds / timer.wait_time
	indicator.call("set_remaining_fraction", fraction)


func _on_purchase_timeout() -> void:
	if state != "waiting_for_player":
		return
	var debug_item_id := str(_purchase_preview.get("item_id", ""))
	var item_id := str(_purchase_preview.get("item_id", PrototypeConstants.ITEM_APPLE))
	var item_price := int(_purchase_preview.get("price", 0))
	_clear_purchase_request()
	GameState.record_rejection()
	GameState.record_customer_served()
	SignalBus.sale_feedback.emit("顾客等不及走了", global_position)
	_show_customer_dialogue(CustomerDialogueLines.EVENT_TIMEOUT, item_id, item_price, "顾客等不及走了")
	GameplayDebugLog.log("customer", "purchase_timeout", {
		"customer_type": customer_type,
		"item_id": debug_item_id,
	})
	state = "leaving"


func _on_stall_closed_node(closed_stall: Node) -> void:
	if state != "waiting_for_player" or _purchase_stall != closed_stall:
		return
	var item_id := str(_purchase_preview.get("item_id", PrototypeConstants.ITEM_APPLE))
	var item_price := int(_purchase_preview.get("price", 0))
	_clear_purchase_request()
	GameState.record_rejection()
	GameState.record_customer_served()
	var reason := "顾客看到收摊离开了"
	SignalBus.sale_feedback.emit(reason, global_position)
	SignalBus.customer_decision.emit(customer_type, false, reason)
	_show_customer_dialogue(CustomerDialogueLines.EVENT_STALL_CLOSED, item_id, item_price, reason)
	GameplayDebugLog.log("customer", "stall_closed_while_waiting", {
		"customer_type": customer_type,
		"reason": reason,
	})
	state = "leaving"


func _on_stall_inventory_changed(_slots: Array, _stock: int) -> void:
	if state != "waiting_for_player" or _purchase_stall == null or not is_instance_valid(_purchase_stall):
		return
	if _purchase_item_is_still_available():
		return
	var item_id := str(_purchase_preview.get("item_id", ""))
	var item_price := int(_purchase_preview.get("price", 0))
	var reason := "%s卖完了，顾客离开了" % ConfigLoader.get_item_name(item_id)
	_clear_purchase_request()
	GameState.record_rejection()
	GameState.record_customer_served()
	SignalBus.sale_feedback.emit(reason, global_position)
	SignalBus.customer_decision.emit(customer_type, false, reason)
	_show_customer_dialogue(CustomerDialogueLines.EVENT_NO_INTEREST, item_id, item_price, reason)
	GameplayDebugLog.log("customer", "purchase_item_sold_out_while_waiting", {
		"customer_type": customer_type,
		"item_id": item_id,
		"reason": reason,
	})
	state = "leaving"


func _purchase_item_is_still_available() -> bool:
	var item_id := str(_purchase_preview.get("item_id", ""))
	if item_id.is_empty():
		return int(_purchase_stall.get("stock")) > 0
	var raw_slots: Variant = _purchase_stall.get("stall_slots")
	if typeof(raw_slots) != TYPE_ARRAY:
		return int(_purchase_stall.get("stock")) > 0
	var slots: Array = raw_slots as Array
	for slot in slots:
		if typeof(slot) != TYPE_DICTIONARY:
			continue
		var item_slot: Dictionary = slot
		if str(item_slot.get("item_id", "")) == item_id and int(item_slot.get("count", 0)) > 0:
			return true
	return false


func _clear_purchase_request() -> void:
	_purchase_stall = null
	_purchase_preview = {}
	for node_name in ["PurchaseInteraction", "PurchaseCountdown", "PurchaseTimer", "PurchaseTickTimer"]:
		var node := get_node_or_null(node_name)
		if node != null:
			remove_child(node)
			node.queue_free()


func _apply_customer_spriteframes() -> void:
	if not is_node_ready():
		return
	visual.sprite_frames = _spriteframes_for_visual()
	var animation := "walk_%s" % facing
	if visual.sprite_frames != null and visual.sprite_frames.has_animation(animation):
		visual.play(animation)


func _spriteframes_for_visual() -> SpriteFrames:
	match visual_variant:
		PrototypeConstants.CUSTOMER_VISUAL_YOUTH_MALE:
			return STUDENT_FRAMES
		PrototypeConstants.CUSTOMER_VISUAL_YOUTH_FEMALE:
			return YOUTH_FEMALE_FRAMES
		PrototypeConstants.CUSTOMER_VISUAL_MIDDLE_MALE:
			return WORKER_FRAMES
		PrototypeConstants.CUSTOMER_VISUAL_MIDDLE_FEMALE:
			return FEMALE_MIDDLE_FRAMES
		PrototypeConstants.CUSTOMER_VISUAL_ELDER_MALE:
			return ELDER_MALE_FRAMES
		PrototypeConstants.CUSTOMER_VISUAL_ELDER_FEMALE:
			return FEMALE_ELDER_FRAMES
	return WORKER_FRAMES if customer_type == PrototypeConstants.CUSTOMER_WORKER else STUDENT_FRAMES


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


func _walk_to_exit(delta: float) -> void:
	if _route_points.is_empty():
		_route_points.append(exit_position)
	var target := _route_points[min(_route_index, _route_points.size() - 1)]
	if _move_towards(target, delta):
		_insert_detour_before_current_route_target(target)
		_reset_stuck_tracking()
		return
	if global_position.distance_to(target) < 10.0:
		_route_index += 1
		_reset_stuck_tracking()
	if _route_index >= _route_points.size() or (Time.get_ticks_msec() / 1000.0) - _started_at > _route_timeout_seconds:
		queue_free()


func _calculate_route_timeout(start_position: Vector2, route_points: Array[Vector2]) -> float:
	var distance := 0.0
	var previous := start_position
	for point in route_points:
		distance += previous.distance_to(point)
		previous = point
	return max(18.0, distance / SPEED + ROUTE_TIMEOUT_PADDING_SECONDS)


func _should_visit_stall(active_stall: Node) -> bool:
	if active_stall == null or not is_instance_valid(active_stall):
		return false
	if not bool(active_stall.get("is_open")) or int(active_stall.get("stock")) <= 0:
		return false
	return not _stall_dialogue_item(active_stall).is_empty()


func _visit_target_for_stall(active_stall: Node) -> Vector2:
	if _visit_target_stall == active_stall:
		return _visit_target_position
	_visit_target_stall = active_stall
	if active_stall.has_method("get_customer_approach_position"):
		_visit_target_position = active_stall.call("get_customer_approach_position", global_position)
	else:
		var stall_node := active_stall as Node2D
		_visit_target_position = stall_node.global_position + Vector2(0, 96)
	return _visit_target_position


func _abandon_stall_visit() -> void:
	_influence_stall = null
	_visit_target_stall = null
	_reset_stuck_tracking()


func _insert_detour_before_current_route_target(target: Vector2) -> void:
	var insert_index := clampi(_route_index, 0, _route_points.size())
	var replacement_points := _reroute_points_for_target(target)
	for index in range(replacement_points.size() - 1, -1, -1):
		_route_points.insert(insert_index, replacement_points[index])


func _reroute_points_for_target(target: Vector2) -> Array[Vector2]:
	var navigator := _road_navigator()
	if navigator != null:
		var road_path: Array = []
		if navigator.has_method("find_randomized_path"):
			road_path = navigator.call("find_randomized_path", global_position, target, _rng)
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
		_maybe_show_stall_seen_dialogue(stall)


func exit_stall_influence(stall: Node) -> void:
	if stall == _influence_stall and state == "walking":
		_influence_stall = null
		_visit_target_stall = null
		_reset_stuck_tracking()


func consider_begging_donation(begging_session: Node) -> void:
	if state != "walking" or begging_session == null or not is_instance_valid(begging_session):
		return
	var session_id := begging_session.get_instance_id()
	if _begging_session_ids.has(session_id):
		return
	_begging_session_ids[session_id] = true
	if _rng.randf() > _begging_donation_chance():
		return
	if begging_session.has_method("receive_donation"):
		begging_session.call("receive_donation", self)


func _has_demand_for(item_id: String) -> bool:
	return _preference_for(item_id) >= DEMAND_THRESHOLD


func _maybe_show_stall_seen_dialogue(stall: Node) -> void:
	if state != "walking" or stall == null or not is_instance_valid(stall):
		return
	var item := _stall_dialogue_item(stall)
	if item.is_empty():
		return
	_dialogue_feedback_component().call("maybe_show_stall_seen", stall, item)


func _show_customer_dialogue(event: String, item_id: String, price: int, reason: String) -> void:
	_dialogue_feedback_component().call("show_dialogue", event, item_id, price, reason)


func _stall_dialogue_item(stall: Node) -> Dictionary:
	var best_item := {}
	var best_preference := -1.0
	var raw_slots: Variant = stall.get("stall_slots")
	if typeof(raw_slots) == TYPE_ARRAY:
		var slots: Array = raw_slots as Array
		for slot in slots:
			if typeof(slot) != TYPE_DICTIONARY:
				continue
			var item_slot: Dictionary = slot
			var item_id := str(item_slot.get("item_id", ""))
			if item_id.is_empty() or int(item_slot.get("count", 0)) <= 0:
				continue
			var preference := _preference_for(item_id)
			if preference < DEMAND_THRESHOLD or preference <= best_preference:
				continue
			best_preference = preference
			best_item = {
				"item_id": item_id,
				"price": int(item_slot.get("price", ConfigLoader.get_base_sell_price(item_id))),
			}
	if not best_item.is_empty():
		return best_item
	var fallback_item_id := str(stall.get("current_item_id"))
	if fallback_item_id.is_empty() or not _has_demand_for(fallback_item_id):
		return {}
	return {
		"item_id": fallback_item_id,
		"price": int(stall.get("price")),
	}


func _preference_for(item_id: String) -> float:
	var preferences: Dictionary = _customer_profile.get("preferences", {})
	return float(preferences.get(item_id, 0.0))


func _dialogue_feedback_component() -> Node:
	if _dialogue_feedback != null and is_instance_valid(_dialogue_feedback):
		_dialogue_feedback.call("set_customer_profile", _customer_profile)
		return _dialogue_feedback
	_dialogue_feedback = Node.new()
	_dialogue_feedback.name = "DialogueFeedback"
	_dialogue_feedback.set_script(CustomerDialogueFeedback)
	add_child(_dialogue_feedback)
	_dialogue_feedback.call("configure", self, _customer_profile, _rng)
	return _dialogue_feedback


func get_current_dialogue_text() -> String:
	return str(_dialogue_feedback_component().call("get_current_text"))


func set_dialogue_chance_override(event: String, chance: float) -> void:
	_dialogue_feedback_component().call("set_chance_override", event, chance)


func get_purchase_prompt() -> String:
	var item_id := str(_purchase_preview.get("item_id", PrototypeConstants.ITEM_APPLE))
	return "确认卖%s" % ConfigLoader.get_item_name(item_id)


func _begging_donation_chance() -> float:
	var budget := int(_customer_profile.get("budget", 2))
	if budget <= 0:
		return 0.0
	var chance := 0.05 + clampf(float(budget) / 10.0, 0.0, 1.0) * 0.25
	match age_group:
		PrototypeConstants.CUSTOMER_AGE_YOUTH:
			chance -= 0.02
		PrototypeConstants.CUSTOMER_AGE_MIDDLE:
			chance += 0.04
		PrototypeConstants.CUSTOMER_AGE_ELDER:
			chance += 0.08
	if gender == PrototypeConstants.CUSTOMER_GENDER_FEMALE:
		chance += 0.03
	return clampf(chance, 0.02, 0.50)


func _build_customer_profile() -> void:
	_rng.randomize()
	var base_profile := _base_profile_for_demographic(age_group, gender)
	var base_budget := int(base_profile.get("budget", 2))
	var base_preferences: Dictionary = base_profile.get("preferences", {})
	var budget_range := ConfigLoader.get_customer_personal_budget_range()
	var personal_budget := _rng.randi_range(budget_range.x, budget_range.y)
	var personal_preferences := _build_personal_preferences()
	var final_preferences := _blend_preferences(base_preferences, personal_preferences)
	_customer_profile = {
		"age_group": age_group,
		"gender": gender,
		"label": _demographic_label(),
		"budget": int(round((float(base_budget) + float(personal_budget)) * 0.5)),
		"base_budget": base_budget,
		"personal_budget": personal_budget,
		"preferences": final_preferences,
		"base_preferences": base_preferences.duplicate(true),
		"personal_preferences": personal_preferences,
	}


func get_customer_profile() -> Dictionary:
	return _customer_profile.duplicate(true)


func _apply_default_demographics() -> void:
	if age_group.is_empty():
		age_group = _default_age_group()
	if gender.is_empty():
		gender = _default_gender()


func _default_age_group() -> String:
	match visual_variant:
		PrototypeConstants.CUSTOMER_VISUAL_YOUTH_MALE, PrototypeConstants.CUSTOMER_VISUAL_YOUTH_FEMALE:
			return PrototypeConstants.CUSTOMER_AGE_YOUTH
		PrototypeConstants.CUSTOMER_VISUAL_MIDDLE_MALE, PrototypeConstants.CUSTOMER_VISUAL_MIDDLE_FEMALE:
			return PrototypeConstants.CUSTOMER_AGE_MIDDLE
		PrototypeConstants.CUSTOMER_VISUAL_ELDER_MALE, PrototypeConstants.CUSTOMER_VISUAL_ELDER_FEMALE:
			return PrototypeConstants.CUSTOMER_AGE_ELDER
	if customer_type == PrototypeConstants.CUSTOMER_STUDENT:
		return PrototypeConstants.CUSTOMER_AGE_YOUTH
	return PrototypeConstants.CUSTOMER_AGE_MIDDLE


func _default_gender() -> String:
	match visual_variant:
		PrototypeConstants.CUSTOMER_VISUAL_YOUTH_FEMALE, PrototypeConstants.CUSTOMER_VISUAL_MIDDLE_FEMALE, PrototypeConstants.CUSTOMER_VISUAL_ELDER_FEMALE:
			return PrototypeConstants.CUSTOMER_GENDER_FEMALE
		PrototypeConstants.CUSTOMER_VISUAL_YOUTH_MALE, PrototypeConstants.CUSTOMER_VISUAL_MIDDLE_MALE, PrototypeConstants.CUSTOMER_VISUAL_ELDER_MALE:
			return PrototypeConstants.CUSTOMER_GENDER_MALE
	return PrototypeConstants.CUSTOMER_GENDER_MALE


func _base_profile_for_demographic(next_age_group: String, next_gender: String) -> Dictionary:
	return ConfigLoader.get_customer_base_profile(next_age_group, next_gender)


func _build_personal_preferences() -> Dictionary:
	var preferences := {}
	for item_id in ConfigLoader.get_customer_preference_items():
		var preference_range := ConfigLoader.get_customer_personal_preference_range(item_id)
		preferences[item_id] = _rng.randf_range(preference_range.x, preference_range.y)
	return preferences


func _blend_preferences(base_preferences: Dictionary, personal_preferences: Dictionary) -> Dictionary:
	var blended := {}
	for item_id in ConfigLoader.get_customer_preference_items():
		var base_value := float(base_preferences.get(item_id, 0.45))
		var personal_value := float(personal_preferences.get(item_id, 0.45))
		blended[item_id] = (base_value + personal_value) * 0.5
	return blended


func _demographic_label() -> String:
	var age_label := str(PrototypeConstants.CUSTOMER_AGE_LABELS.get(age_group, "顾客"))
	var gender_label := str(PrototypeConstants.CUSTOMER_GENDER_LABELS.get(gender, ""))
	return "%s%s" % [age_label, gender_label]
