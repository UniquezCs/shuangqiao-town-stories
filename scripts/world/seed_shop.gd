extends Area2D


func _ready() -> void:
	add_to_group("interactable")


func get_prompt() -> String:
	return "购买苹果种子 2 元"


func interact(_player: Node) -> void:
	if GameState.spend_cash(PrototypeConstants.SEED_PRICE):
		Inventory.add_item(PrototypeConstants.ITEM_APPLE_SEED, 1)
		SignalBus.sale_feedback.emit("买到苹果种子", global_position)
		if GameState.cash >= 0 and Inventory.get_count(PrototypeConstants.ITEM_APPLE_SEED) > 0:
			GameState.set_objective("把种子种回地里")
	else:
		SignalBus.sale_feedback.emit("钱不够", global_position)
