extends CharacterBody2D

signal interactable_changed(prompt: String)

const SPEED := 120.0
const FARMING_ACTIONS := {
	"hoe": true,
	"water": true,
	"harvest": true,
}
const FARMING_CLICK_TOOLS := {
	PrototypeConstants.TOOL_HOE: true,
	PrototypeConstants.TOOL_SEED: true,
	PrototypeConstants.TOOL_WATER: true,
	PrototypeConstants.TOOL_SICKLE: true,
	PrototypeConstants.TOOL_FERTILIZER: true,
}
const CircularCountdownScript := preload("res://scripts/ui/circular_countdown_indicator.gd")
const BEGGING_KNEEL_TEXTURE_PATH := "res://assets/generated/sprites/characters/vendor_beg_kneel_48x64.png"
const BEGGING_KOWTOW_TEXTURE_PATH := "res://assets/generated/sprites/characters/vendor_beg_kowtow_48x64.png"

var facing := "down"
var _nearby_interactables: Array[Area2D] = []
var _current_interactable: Area2D = null
var _is_farming_action_playing := false
var _hold_interactable: Area2D = null
var _is_begging := false
var _begging_pose: Sprite2D = null
var _begging_pose_token := 0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea


func _ready() -> void:
	add_to_group("player")
	animated_sprite.play("walk_down")
	animated_sprite.pause()
	animated_sprite.animation_finished.connect(_on_animation_finished)
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)
	SignalBus.current_tool_changed.connect(_on_current_tool_changed)
	SignalBus.sale_completed.connect(_on_sale_completed)
	_update_interactable()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _is_farming_click_tool(GameState.current_tool):
				get_viewport().set_input_as_handled()
				handle_farming_click(get_global_mouse_position())


func _physics_process(_delta: float) -> void:
	if _hold_interactable != null:
		if not Input.is_action_pressed("interact") or not is_instance_valid(_hold_interactable):
			_cancel_hold_interact()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _is_farming_action_playing:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _is_begging:
		velocity = Vector2.ZERO
		move_and_slide()
		if Input.is_action_just_pressed("interact") and _current_interactable != null:
			if _requires_hold_interact(_current_interactable):
				_start_hold_interact(_current_interactable)
			else:
				_current_interactable.call("interact", self)
		_update_interactable()
		return

	var direction := _input_direction()
	velocity = direction * SPEED
	
	move_and_slide()
	_update_animation(direction)

	if Input.is_action_just_pressed("interact") and _current_interactable != null:
		if _requires_hold_interact(_current_interactable):
			_start_hold_interact(_current_interactable)
		else:
			_current_interactable.call("interact", self)

	_update_interactable()


func _input_direction() -> Vector2:
	var direction := Vector2.ZERO
	direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	return direction.normalized()


func handle_farming_click(world_position: Vector2) -> bool:
	if _hold_interactable != null or _is_farming_action_playing or _is_begging:
		return false
	if not _is_farming_click_tool(GameState.current_tool):
		return false
	var target := _nearest_farming_target(world_position)
	if target.is_empty():
		return false
	var target_position: Vector2 = target.get("world_position", world_position)
	if not _is_farming_target_in_reach(target_position):
		return false
	var target_node: Node = target.get("node", null)
	if target_node == null or not is_instance_valid(target_node) or not target_node.has_method("click_interact"):
		return false
	return bool(await target_node.call("click_interact", target_position, self))


func play_farming_action(action_id: String) -> void:
	if _is_begging:
		return
	var action := action_id.strip_edges()
	if not FARMING_ACTIONS.has(action):
		return
	var animation := "%s_%s" % [action, facing]
	if animated_sprite.sprite_frames == null or not animated_sprite.sprite_frames.has_animation(animation):
		return
	_is_farming_action_playing = true
	velocity = Vector2.ZERO
	animated_sprite.play(animation)


func _update_animation(direction: Vector2) -> void:
	if _is_farming_action_playing:
		return

	if direction.length() > 0.0:
		if abs(direction.x) > abs(direction.y):
			facing = "right" if direction.x > 0.0 else "left"
		else:
			facing = "down" if direction.y > 0.0 else "up"
		animated_sprite.play("walk_%s" % facing)
	else:
		var animation := "walk_%s" % facing
		if animated_sprite.animation != animation:
			animated_sprite.play(animation)
		animated_sprite.frame = 0
		animated_sprite.pause()


func _on_interaction_area_entered(area: Area2D) -> void:
	if area.is_in_group("interactable") and not _nearby_interactables.has(area):
		_nearby_interactables.append(area)
		_update_interactable()


func _on_interaction_area_exited(area: Area2D) -> void:
	_nearby_interactables.erase(area)
	if area == _hold_interactable:
		_cancel_hold_interact()
	_update_interactable()


func _update_interactable() -> void:
	_nearby_interactables = _nearby_interactables.filter(func(area: Area2D) -> bool:
		return is_instance_valid(area) and area.is_inside_tree() and area.is_in_group("interactable")
	)

	var nearest: Area2D = null
	var nearest_distance := INF
	for area in _nearby_interactables:
		var distance := global_position.distance_to(area.global_position)
		if distance < nearest_distance:
			nearest = area
			nearest_distance = distance

	if nearest == _current_interactable:
		return

	_current_interactable = nearest
	var prompt := ""
	if _current_interactable != null and _current_interactable.has_method("get_prompt"):
		prompt = str(_current_interactable.call("get_prompt"))
	interactable_changed.emit(prompt)
	SignalBus.interaction_prompt_changed.emit(prompt)


func _on_current_tool_changed(_tool_id: String) -> void:
	call_deferred("_refresh_overlapping_interactables")


func _refresh_overlapping_interactables() -> void:
	for area in interaction_area.get_overlapping_areas():
		if area.is_in_group("interactable") and not _nearby_interactables.has(area):
			_nearby_interactables.append(area)
	_update_interactable()


func _requires_hold_interact(area: Area2D) -> bool:
	return area.has_method("requires_hold_interact") and bool(area.call("requires_hold_interact"))


func _start_hold_interact(area: Area2D) -> void:
	if _hold_interactable != null:
		_cancel_hold_interact()
	_hold_interactable = area
	if area.has_method("begin_hold_interact"):
		area.call("begin_hold_interact", self)

	var duration := PrototypeConstants.STALL_CLOSE_HOLD_SECONDS
	if area.has_method("get_hold_interact_duration"):
		duration = maxf(0.1, float(area.call("get_hold_interact_duration")))

	var timer := Timer.new()
	timer.name = "StallCloseHoldTimer"
	timer.one_shot = true
	timer.wait_time = duration
	timer.timeout.connect(_complete_hold_interact)
	add_child(timer)
	timer.start()

	var tick_timer := Timer.new()
	tick_timer.name = "StallCloseHoldTickTimer"
	tick_timer.wait_time = 0.05
	tick_timer.timeout.connect(_update_hold_countdown)
	add_child(tick_timer)
	tick_timer.start()

	var countdown := Node2D.new()
	countdown.name = "StallCloseCountdown"
	countdown.set_script(CircularCountdownScript)
	countdown.position = Vector2(0, -96)
	add_child(countdown)
	countdown.call("set_remaining_fraction", 1.0)


func _cancel_hold_interact() -> void:
	var area := _hold_interactable
	_hold_interactable = null
	if area != null and is_instance_valid(area) and area.has_method("cancel_hold_interact"):
		area.call("cancel_hold_interact", self)
	_clear_hold_countdown()


func _complete_hold_interact() -> void:
	var area := _hold_interactable
	_hold_interactable = null
	_clear_hold_countdown()
	if area == null or not is_instance_valid(area):
		return
	if area.has_method("complete_hold_interact"):
		area.call("complete_hold_interact", self)
	elif area.has_method("interact"):
		area.call("interact", self)


func _update_hold_countdown() -> void:
	var timer := get_node_or_null("StallCloseHoldTimer") as Timer
	var countdown := get_node_or_null("StallCloseCountdown")
	if timer == null or countdown == null or not countdown.has_method("set_remaining_fraction"):
		return
	var fraction := 0.0 if timer.wait_time <= 0.0 else timer.time_left / timer.wait_time
	countdown.call("set_remaining_fraction", fraction)


func _clear_hold_countdown() -> void:
	for node_name in ["StallCloseHoldTimer", "StallCloseHoldTickTimer", "StallCloseCountdown"]:
		var node := get_node_or_null(node_name)
		if node != null:
			remove_child(node)
			node.queue_free()


func _on_animation_finished() -> void:
	if not _is_farming_action_playing:
		return
	_is_farming_action_playing = false
	_update_animation(Vector2.ZERO)


func _on_sale_completed(_item_id: String, price: int, _remaining_stock: int) -> void:
	show_cash_popup(price)


func enter_begging_state() -> void:
	_is_begging = true
	velocity = Vector2.ZERO
	animated_sprite.visible = false
	_ensure_begging_pose().texture = _load_texture(BEGGING_KNEEL_TEXTURE_PATH)


func exit_begging_state() -> void:
	_is_begging = false
	if _begging_pose != null and is_instance_valid(_begging_pose):
		_begging_pose.queue_free()
	_begging_pose = null
	animated_sprite.visible = true
	_update_animation(Vector2.ZERO)


func is_begging() -> bool:
	return _is_begging


func play_begging_kowtow() -> void:
	if not _is_begging:
		return
	var pose := _ensure_begging_pose()
	_begging_pose_token += 1
	var token := _begging_pose_token
	pose.texture = _load_texture(BEGGING_KOWTOW_TEXTURE_PATH)
	await get_tree().create_timer(0.35).timeout
	if _is_begging and _begging_pose != null and is_instance_valid(_begging_pose) and token == _begging_pose_token:
		_begging_pose.texture = _load_texture(BEGGING_KNEEL_TEXTURE_PATH)


func show_cash_popup(amount: int) -> void:
	var old_popup := get_node_or_null("SaleAmountPopup")
	if old_popup != null:
		old_popup.queue_free()

	var popup := Label.new()
	popup.name = "SaleAmountPopup"
	popup.text = "+%d 元" % amount
	popup.position = Vector2(-24, -76)
	popup.z_index = 100
	popup.add_theme_font_size_override("font_size", 18)
	popup.add_theme_color_override("font_color", Color(1.0, 0.86, 0.25, 1.0))
	popup.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	popup.add_theme_constant_override("shadow_offset_x", 1)
	popup.add_theme_constant_override("shadow_offset_y", 1)
	add_child(popup)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 28.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.8).set_delay(0.15)
	tween.finished.connect(func() -> void:
		if is_instance_valid(popup):
			popup.queue_free()
	)


func _ensure_begging_pose() -> Sprite2D:
	if _begging_pose != null and is_instance_valid(_begging_pose):
		return _begging_pose
	_begging_pose = Sprite2D.new()
	_begging_pose.name = "BeggingPose"
	_begging_pose.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_begging_pose.position = animated_sprite.position
	_begging_pose.z_index = animated_sprite.z_index
	add_child(_begging_pose)
	return _begging_pose


func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _is_farming_click_tool(tool_id: String) -> bool:
	return FARMING_CLICK_TOOLS.has(tool_id)


func _nearest_farming_target(world_position: Vector2) -> Dictionary:
	if GameState.current_tool == PrototypeConstants.TOOL_HOE:
		return _nearest_farm_field_target(world_position)
	return _nearest_farm_plot_target(world_position)


func _nearest_farm_field_target(world_position: Vector2) -> Dictionary:
	var nearest := {}
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("farm_field"):
		if not is_instance_valid(node) or not node.has_method("nearest_click_target"):
			continue
		var target: Dictionary = node.call("nearest_click_target", world_position)
		if target.is_empty():
			continue
		var target_position: Vector2 = target.get("world_position", world_position)
		var distance := world_position.distance_to(target_position)
		if distance < nearest_distance:
			nearest = target
			nearest_distance = distance
	return nearest


func _nearest_farm_plot_target(world_position: Vector2) -> Dictionary:
	var nearest_plot: Node2D = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("farm_plot"):
		var plot := node as Node2D
		if plot == null or not is_instance_valid(plot):
			continue
		var distance := world_position.distance_to(plot.global_position)
		if distance < nearest_distance:
			nearest_plot = plot
			nearest_distance = distance
	if nearest_plot == null:
		return {}
	if nearest_distance > PrototypeConstants.FARM_CLICK_TARGET_RADIUS:
		return {}
	return {
		"world_position": nearest_plot.global_position,
		"node": nearest_plot,
	}


func _is_farming_target_in_reach(target_position: Vector2) -> bool:
	return global_position.distance_to(target_position) <= PrototypeConstants.FARM_CLICK_REACH_RADIUS
