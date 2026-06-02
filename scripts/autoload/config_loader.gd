extends Node

const ITEMS_PATH := "res://configs/items.json"
const CROPS_PATH := "res://configs/crops.json"
const UPGRADES_PATH := "res://configs/upgrades.json"
const ASSETS_PATH := "res://configs/assets.json"

var items: Dictionary = {}
var crops: Dictionary = {}
var upgrades: Dictionary = {}
var assets: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	items = _load_json(ITEMS_PATH)
	crops = _load_json(CROPS_PATH)
	upgrades = _load_json(UPGRADES_PATH)
	assets = _load_json(ASSETS_PATH)


func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})


func get_item_name(item_id: String) -> String:
	return str(get_item(item_id).get("name", PrototypeConstants.ITEM_LABELS.get(item_id, item_id)))


func get_stack_size(item_id: String) -> int:
	return maxi(1, int(get_item(item_id).get("stack_size", 99)))


func get_item_icon(item_id: String) -> String:
	return str(get_item(item_id).get("icon", ""))


func get_base_sell_price(item_id: String) -> int:
	return clampi(int(get_item(item_id).get("base_sell_price", PrototypeConstants.MIN_APPLE_PRICE)), PrototypeConstants.MIN_APPLE_PRICE, PrototypeConstants.MAX_APPLE_PRICE)


func is_sellable_item(item_id: String) -> bool:
	return str(get_item(item_id).get("category", "")) == "crop"


func get_crop_for_seed(seed_item_id: String) -> String:
	for crop_id in crops.keys():
		var crop: Dictionary = crops[crop_id]
		if str(crop.get("seed_item_id", "")) == seed_item_id:
			return str(crop_id)
	return ""


func get_crop(crop_id: String) -> Dictionary:
	return crops.get(crop_id, {})


func get_upgrade_entry(upgrade_id: String, level: int) -> Dictionary:
	var entries: Array = upgrades.get(upgrade_id, [])
	for entry in entries:
		if int(entry.get("level", 0)) == level:
			return entry
	return {}


func get_next_upgrade_entry(upgrade_id: String, level: int) -> Dictionary:
	return get_upgrade_entry(upgrade_id, level + 1)


func get_asset(asset_id: String) -> Dictionary:
	return _find_asset_entry(assets, asset_id)


func get_asset_path(asset_id: String) -> String:
	var entry := get_asset(asset_id)
	return str(entry.get("path", entry.get("current_texture", entry.get("spriteframes", ""))))


func _find_asset_entry(root: Variant, asset_id: String) -> Dictionary:
	if typeof(root) == TYPE_DICTIONARY:
		if str(root.get("id", "")) == asset_id:
			return root
		for key in root.keys():
			if str(key) == asset_id and typeof(root[key]) == TYPE_DICTIONARY:
				return root[key]
			var found := _find_asset_entry(root[key], asset_id)
			if not found.is_empty():
				return found
	elif typeof(root) == TYPE_ARRAY:
		for item in root:
			var found := _find_asset_entry(item, asset_id)
			if not found.is_empty():
				return found
	return {}


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("配置文件不存在：%s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("配置文件格式错误：%s" % path)
		return {}
	return parsed
