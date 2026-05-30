extends Node2D

const STALL_TEXTURES := [
	preload("res://assets/generated/sprites/props/stall/01_stall_empty.png"),
	preload("res://assets/generated/sprites/props/stall/04_stall_apple_1.png"),
	preload("res://assets/generated/sprites/props/stall/03_stall_apples_3.png"),
	preload("res://assets/generated/sprites/props/stall/02_stall_apples_6.png"),
]

var spot_id := ""
var is_open := false
var stock := 0
var price := 2
var current_item_id := PrototypeConstants.ITEM_APPLE
@export var influence_radius := 160.0

var _influence_area: Area2D = null
var _inspection_target: Area2D = null
var _player_boundary: StaticBody2D = null

@onready var visual: Sprite2D = $Visual


func _ready() -> void:
	_refresh_visual()


func open(spot: String, chosen_price: int, owner: Node2D = null) -> bool:
	if is_open:
		return false
	current_item_id = Inventory.get_first_sellable_item_id()
	if current_item_id.is_empty():
		current_item_id = PrototypeConstants.ITEM_APPLE
	var available := Inventory.get_count(current_item_id)
	if available <= 0:
		SignalBus.sale_feedback.emit("背包里没有可卖的商品", global_position)
		return false
	if owner != null and is_instance_valid(owner):
		global_position = owner.global_position
	spot_id = spot
	price = clamp(chosen_price, PrototypeConstants.MIN_APPLE_PRICE, PrototypeConstants.MAX_APPLE_PRICE)
	influence_radius = GameState.get_stall_influence_radius()
	stock = min(available, GameState.get_stall_stock_limit())
	Inventory.remove_item(current_item_id, stock)
	is_open = true
	visible = true
	GameState.record_stall_use(spot_id)
	GameState.set_objective("等顾客来买%s" % ConfigLoader.get_item_name(current_item_id))
	SignalBus.stall_opened.emit(spot_id, price, stock)
	SignalBus.stall_stock_changed.emit(stock)
	SignalBus.price_changed.emit(price)
	_create_influence_area()
	_create_inspection_target()
	_create_player_boundary()
	_refresh_visual()
	return true


func close() -> void:
	if not is_open:
		return
	var returned := stock
	if returned > 0:
		Inventory.add_item(current_item_id, returned)
	stock = 0
	is_open = false
	visible = false
	SignalBus.stall_closed.emit(spot_id, returned)
	SignalBus.stall_stock_changed.emit(stock)
	GameState.set_objective("可以换点摆摊，或回家买种子")
	_remove_influence_area()
	_remove_inspection_target()
	_remove_player_boundary()
	_refresh_visual()


func can_sell_to(customer_type: String, customer_profile: Dictionary = {}) -> Dictionary:
	if not is_open or stock <= 0:
		return {"bought": false, "reason": "没货了"}
	if not customer_profile.is_empty():
		return _profile_decision(customer_type, customer_profile)
	if customer_type == PrototypeConstants.CUSTOMER_STUDENT:
		if price <= 2:
			return {"bought": true, "reason": "学生买下苹果"}
		if price == 3:
			return {"bought": false, "reason": "学生觉得有点贵"}
		return {"bought": false, "reason": "学生买不起"}
	if customer_type == PrototypeConstants.CUSTOMER_WORKER:
		if price <= 4:
			return {"bought": true, "reason": "工人买下苹果"}
		return {"bought": false, "reason": "工人觉得贵"}
	return {"bought": false, "reason": "顾客离开"}


func sell_one(customer_type: String, customer_profile: Dictionary = {}) -> Dictionary:
	var decision := can_sell_to(customer_type, customer_profile)
	if bool(decision["bought"]):
		stock -= 1
		GameState.record_sale(price)
		GameState.record_customer_served()
		SignalBus.stall_stock_changed.emit(stock)
		SignalBus.sale_completed.emit(current_item_id, price, stock)
		SignalBus.sale_feedback.emit("+%d 元" % price, global_position)
		if stock <= 0:
			GameState.set_objective("%s卖完了，可以回家补货" % ConfigLoader.get_item_name(current_item_id))
		_refresh_visual()
	else:
		GameState.record_rejection()
		GameState.record_customer_served()
		SignalBus.sale_feedback.emit(str(decision["reason"]), global_position)
	SignalBus.customer_decision.emit(customer_type, bool(decision["bought"]), str(decision["reason"]))
	return decision


func _create_influence_area() -> void:
	if _influence_area != null and is_instance_valid(_influence_area):
		return
	_influence_area = Area2D.new()
	_influence_area.name = "InfluenceArea"
	_influence_area.collision_layer = 0
	_influence_area.collision_mask = 4
	_influence_area.monitorable = false
	_influence_area.monitoring = true
	_influence_area.body_entered.connect(_on_influence_body_entered)
	_influence_area.body_exited.connect(_on_influence_body_exited)

	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = influence_radius
	collision_shape.shape = circle
	_influence_area.add_child(collision_shape)
	add_child(_influence_area)


func _remove_influence_area() -> void:
	if _influence_area == null or not is_instance_valid(_influence_area):
		_influence_area = null
		return
	_influence_area.queue_free()
	_influence_area = null


func _create_inspection_target() -> void:
	if _inspection_target != null and is_instance_valid(_inspection_target):
		return
	_inspection_target = Area2D.new()
	_inspection_target.name = "InspectionTarget"
	_inspection_target.add_to_group("open_stall_inspection_target")
	_inspection_target.collision_layer = 8
	_inspection_target.collision_mask = 0
	_inspection_target.monitoring = false
	_inspection_target.monitorable = true

	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = influence_radius
	collision_shape.shape = circle
	_inspection_target.add_child(collision_shape)
	add_child(_inspection_target)


func _remove_inspection_target() -> void:
	if _inspection_target == null or not is_instance_valid(_inspection_target):
		_inspection_target = null
		return
	_inspection_target.queue_free()
	_inspection_target = null


func _create_player_boundary() -> void:
	if _player_boundary != null and is_instance_valid(_player_boundary):
		return
	_player_boundary = StaticBody2D.new()
	_player_boundary.name = "PlayerBoundary"
	_player_boundary.collision_layer = PrototypeConstants.PLAYER_BOUNDARY_COLLISION_LAYER
	_player_boundary.collision_mask = 0
	add_child(_player_boundary)

	var half_size := PrototypeConstants.STALL_PLAYER_BOUNDARY_HALF_SIZE
	var thickness := PrototypeConstants.STALL_PLAYER_BOUNDARY_WALL_THICKNESS
	_add_boundary_wall(Vector2(0, -half_size - thickness * 0.5), Vector2(half_size * 2.0 + thickness * 2.0, thickness))
	_add_boundary_wall(Vector2(0, half_size + thickness * 0.5), Vector2(half_size * 2.0 + thickness * 2.0, thickness))
	_add_boundary_wall(Vector2(-half_size - thickness * 0.5, 0), Vector2(thickness, half_size * 2.0))
	_add_boundary_wall(Vector2(half_size + thickness * 0.5, 0), Vector2(thickness, half_size * 2.0))


func _add_boundary_wall(local_position: Vector2, size: Vector2) -> void:
	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	collision_shape.position = local_position
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision_shape.shape = rectangle
	_player_boundary.add_child(collision_shape)


func _remove_player_boundary() -> void:
	if _player_boundary == null or not is_instance_valid(_player_boundary):
		_player_boundary = null
		return
	_player_boundary.queue_free()
	_player_boundary = null


func _on_influence_body_entered(body: Node) -> void:
	if is_open and body.has_method("enter_stall_influence"):
		body.call("enter_stall_influence", self)


func _on_influence_body_exited(body: Node) -> void:
	if body.has_method("exit_stall_influence"):
		body.call("exit_stall_influence", self)


func _profile_decision(customer_type: String, customer_profile: Dictionary) -> Dictionary:
	var customer_label := "工人" if customer_type == PrototypeConstants.CUSTOMER_WORKER else "学生"
	var budget := int(customer_profile.get("budget", _default_budget_for(customer_type)))
	var preferences: Dictionary = customer_profile.get("preferences", {})
	var preference := float(preferences.get(current_item_id, preferences.get(PrototypeConstants.ITEM_APPLE, 0.0)))
	if preference < 0.45:
		return {"bought": false, "reason": "%s暂时不想买%s" % [customer_label, ConfigLoader.get_item_name(current_item_id)]}

	var acceptable_price := clampi(int(floor(float(budget) * (0.55 + preference))), 1, budget)
	if price <= acceptable_price:
		return {"bought": true, "reason": "%s买下%s" % [customer_label, ConfigLoader.get_item_name(current_item_id)]}
	if price > budget:
		return {"bought": false, "reason": "%s预算不够" % customer_label}
	return {"bought": false, "reason": "%s觉得不划算" % customer_label}


func _default_budget_for(customer_type: String) -> int:
	if customer_type == PrototypeConstants.CUSTOMER_WORKER:
		return 4
	return 2


func _refresh_visual() -> void:
	if stock <= 0:
		visual.texture = STALL_TEXTURES[0]
	elif stock == 1:
		visual.texture = STALL_TEXTURES[1]
	elif stock <= 3:
		visual.texture = STALL_TEXTURES[2]
	else:
		visual.texture = STALL_TEXTURES[3]
