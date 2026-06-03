extends Node2D

signal ended

const BOWL_TEXTURE_PATH := "res://assets/generated/sprites/props/begging/begging_bowl_32.png"

var is_active := false
var spot_id := ""
var _player: Node2D = null
var _donor_ids := {}
var _bowl: Sprite2D = null
var _influence_area: Area2D = null


func start(next_spot_id: String, player: Node2D) -> void:
	if is_active:
		return
	spot_id = next_spot_id
	_player = player
	is_active = true
	if _player != null and is_instance_valid(_player):
		global_position = _player.global_position
		if _player.has_method("enter_begging_state"):
			_player.call("enter_begging_state")
	_create_bowl()
	_create_influence_area()
	GameState.set_objective("正在乞讨，长按 E 结束")


func stop() -> void:
	if not is_active:
		return
	is_active = false
	if _player != null and is_instance_valid(_player) and _player.has_method("exit_begging_state"):
		_player.call("exit_begging_state")
	_clear_runtime_nodes()
	ended.emit()
	queue_free()


func receive_donation(donor: Node = null) -> void:
	if not is_active:
		return
	if donor != null and is_instance_valid(donor):
		var donor_id := donor.get_instance_id()
		if _donor_ids.has(donor_id):
			return
		_donor_ids[donor_id] = true
	GameState.add_cash(1)
	if _player != null and is_instance_valid(_player):
		if _player.has_method("play_begging_kowtow"):
			_player.call("play_begging_kowtow")
		if _player.has_method("show_cash_popup"):
			_player.call("show_cash_popup", 1)
		else:
			SignalBus.sale_feedback.emit("+1 元", _player.global_position)


func _create_bowl() -> void:
	_bowl = Sprite2D.new()
	_bowl.name = "Bowl"
	_bowl.texture = load(BOWL_TEXTURE_PATH) as Texture2D if ResourceLoader.exists(BOWL_TEXTURE_PATH) else null
	_bowl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bowl.z_index = -1
	_bowl.position = _bowl_offset_for_player()
	add_child(_bowl)


func _create_influence_area() -> void:
	_influence_area = Area2D.new()
	_influence_area.name = "BeggingInfluenceArea"
	_influence_area.collision_layer = 0
	_influence_area.collision_mask = 4
	_influence_area.monitorable = false
	_influence_area.monitoring = true
	_influence_area.body_entered.connect(_on_influence_body_entered)
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = PrototypeConstants.BEGGING_INFLUENCE_RADIUS
	shape_node.shape = circle
	_influence_area.add_child(shape_node)
	add_child(_influence_area)


func _bowl_offset_for_player() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return Vector2(0, 28)
	var player_facing := str(_player.get("facing"))
	match player_facing:
		"up":
			return Vector2(0, -34)
		"left":
			return Vector2(-28, 8)
		"right":
			return Vector2(28, 8)
	return Vector2(0, 30)


func _on_influence_body_entered(body: Node2D) -> void:
	if not is_active or body == null:
		return
	if body.has_method("consider_begging_donation"):
		body.call("consider_begging_donation", self)


func _clear_runtime_nodes() -> void:
	for node in [_influence_area, _bowl]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_influence_area = null
	_bowl = null
