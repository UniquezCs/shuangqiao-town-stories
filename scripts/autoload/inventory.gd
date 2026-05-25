extends Node

var _items: Dictionary = {}


func reset_items() -> void:
	_items = {
		PrototypeConstants.ITEM_APPLE: 0,
		PrototypeConstants.ITEM_APPLE_SEED: 1,
	}
	for item_id in _items.keys():
		SignalBus.inventory_changed.emit(item_id, int(_items[item_id]))


func get_count(item_id: String) -> int:
	return int(_items.get(item_id, 0))


func add_item(item_id: String, amount: int) -> void:
	if amount <= 0:
		return
	_items[item_id] = get_count(item_id) + amount
	SignalBus.inventory_changed.emit(item_id, get_count(item_id))


func remove_item(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	if get_count(item_id) < amount:
		return false
	_items[item_id] = get_count(item_id) - amount
	SignalBus.inventory_changed.emit(item_id, get_count(item_id))
	return true


func set_count(item_id: String, amount: int) -> void:
	_items[item_id] = max(0, amount)
	SignalBus.inventory_changed.emit(item_id, get_count(item_id))
