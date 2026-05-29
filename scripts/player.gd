extends CharacterBody2D

signal interactable_changed(prompt: String)

const SPEED := 120.0

var facing := "down"
var _nearby_interactables: Array[Area2D] = []
var _current_interactable: Area2D = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea


func _ready() -> void:
	add_to_group("player")
	animated_sprite.play("walk_down")
	animated_sprite.pause()
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)
	SignalBus.current_tool_changed.connect(_on_current_tool_changed)
	_update_interactable()


func _physics_process(_delta: float) -> void:
	var direction := _input_direction()
	velocity = direction * SPEED
	
	move_and_slide()
	_update_animation(direction)

	if Input.is_action_just_pressed("interact") and _current_interactable != null:
		_current_interactable.call("interact", self)

	_update_interactable()


func _input_direction() -> Vector2:
	var direction := Vector2.ZERO
	direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	return direction.normalized()


func _update_animation(direction: Vector2) -> void:
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
