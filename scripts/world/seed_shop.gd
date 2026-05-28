extends Area2D


func _ready() -> void:
	add_to_group("interactable")


func get_prompt() -> String:
	return "小卖部：种子 %d 元 / 苹果 %d 元（余 %d）" % [
		PrototypeConstants.SEED_PRICE,
		GameState.seed_shop_apple_price,
		GameState.seed_shop_apple_stock,
	]


func interact(_player: Node) -> void:
	SignalBus.shop_panel_requested.emit(self)


func buy_seed() -> bool:
	if GameState.spend_cash(PrototypeConstants.SEED_PRICE):
		Inventory.add_item(PrototypeConstants.ITEM_APPLE_SEED, 1)
		SignalBus.sale_feedback.emit("买到苹果种子", global_position)
		if GameState.cash >= 0 and Inventory.get_count(PrototypeConstants.ITEM_APPLE_SEED) > 0:
			GameState.set_objective("把种子种回地里")
		return true
	SignalBus.sale_feedback.emit("钱不够", global_position)
	return false


func buy_apple() -> bool:
	if GameState.seed_shop_apple_stock <= 0:
		SignalBus.sale_feedback.emit("今天苹果卖完了", global_position)
		return false
	if not GameState.spend_cash(GameState.seed_shop_apple_price):
		SignalBus.sale_feedback.emit("钱不够", global_position)
		return false
	GameState.seed_shop_apple_stock -= 1
	Inventory.add_item(PrototypeConstants.ITEM_APPLE, 1)
	SignalBus.seed_shop_goods_changed.emit(GameState.seed_shop_apple_price, GameState.seed_shop_apple_stock)
	SignalBus.sale_feedback.emit("买到苹果", global_position)
	GameState.set_objective("把苹果拿去镇街摆摊卖出")
	return true
