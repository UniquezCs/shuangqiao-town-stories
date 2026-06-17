extends Node

const ITEMS_PATH := "res://configs/items.json"
const CROPS_PATH := "res://configs/crops.json"
const UPGRADES_PATH := "res://configs/upgrades.json"
const ASSETS_PATH := "res://configs/assets.json"
const CUSTOMER_PREFERENCES_PATH := "res://configs/customer_preferences.json"
const POPULATION_PATH := "res://configs/population.json"
const FLOW_PREFERENCES_PATH := "res://configs/flow_preferences.json"
const CALENDAR_PATH := "res://configs/calendar.json"

var items: Dictionary = {}
var crops: Dictionary = {}
var upgrades: Dictionary = {}
var assets: Dictionary = {}
var customer_preferences: Dictionary = {}
var population: Dictionary = {}
var flow_preferences: Dictionary = {}
var calendar: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	items = _load_json(ITEMS_PATH, items)
	crops = _load_json(CROPS_PATH, crops)
	upgrades = _load_json(UPGRADES_PATH, upgrades)
	assets = _load_json(ASSETS_PATH, assets)
	customer_preferences = _load_json(CUSTOMER_PREFERENCES_PATH, customer_preferences)
	population = _load_json(POPULATION_PATH, population)
	flow_preferences = _load_json(FLOW_PREFERENCES_PATH, flow_preferences)
	calendar = _load_json(CALENDAR_PATH, calendar)


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


func get_tool_for_item(item_id: String) -> String:
	var item := get_item(item_id)
	var configured_tool := str(item.get("tool_id", ""))
	if not configured_tool.is_empty():
		return configured_tool
	if str(item.get("category", "")) == "seed":
		return PrototypeConstants.TOOL_SEED
	return ""


func get_crop_for_seed(seed_item_id: String) -> String:
	for crop_id in crops.keys():
		var crop: Dictionary = crops[crop_id]
		if str(crop.get("seed_item_id", "")) == seed_item_id:
			return str(crop_id)
	return ""


func get_crop(crop_id: String) -> Dictionary:
	return crops.get(crop_id, {})


func get_crop_state_texture(crop_id: String, state: String) -> String:
	var crop := get_crop(crop_id)
	var textures: Dictionary = crop.get("state_textures", {})
	var path := str(textures.get(state, ""))
	if not path.is_empty():
		return path
	if crop_id != PrototypeConstants.ITEM_APPLE:
		push_warning("作物 %s 缺少 %s 状态贴图配置，临时回退到苹果贴图" % [crop_id, state])
		var apple_crop := get_crop(PrototypeConstants.ITEM_APPLE)
		var apple_textures: Dictionary = apple_crop.get("state_textures", {})
		return str(apple_textures.get(state, ""))
	push_warning("苹果作物缺少 %s 状态贴图配置" % state)
	return ""


func get_seed_shop_seed_items() -> Array[String]:
	var result: Array[String] = []
	for crop_id in crops.keys():
		var crop: Dictionary = crops[crop_id]
		if not bool(crop.get("seed_shop_enabled", false)):
			continue
		var seed_item_id := str(crop.get("seed_item_id", ""))
		if not seed_item_id.is_empty() and items.has(seed_item_id):
			result.append(seed_item_id)
	return result


func get_seed_price(seed_item_id: String) -> int:
	var crop_id := get_crop_for_seed(seed_item_id)
	if crop_id.is_empty():
		return PrototypeConstants.SEED_PRICE
	var crop := get_crop(crop_id)
	return maxi(1, int(crop.get("seed_price", PrototypeConstants.SEED_PRICE)))


func get_customer_preference_items() -> Array[String]:
	var configured_items: Array[String] = _string_array(customer_preferences.get("items", []))
	if not configured_items.is_empty():
		return configured_items
	var sellable_items: Array[String] = []
	for item_id in items.keys():
		var item_key := str(item_id)
		if is_sellable_item(item_key):
			sellable_items.append(item_key)
	return sellable_items


func get_customer_base_profile(age_group: String, gender: String) -> Dictionary:
	var demographics: Dictionary = customer_preferences.get("demographics", {})
	var age_profiles: Dictionary = demographics.get(age_group, demographics.get(PrototypeConstants.CUSTOMER_AGE_MIDDLE, {}))
	var profile: Dictionary = age_profiles.get(gender, age_profiles.get(PrototypeConstants.CUSTOMER_GENDER_MALE, {}))
	var default_budget := int(customer_preferences.get("default_budget", 3))
	return {
		"budget": maxi(1, int(profile.get("budget", default_budget))),
		"preferences": _normalized_customer_preferences(profile.get("preferences", {})),
	}


func get_customer_personal_budget_range() -> Vector2i:
	var raw_range: Array = customer_preferences.get("personal_budget_range", [1, 5])
	if raw_range.size() < 2:
		return Vector2i(1, 5)
	var min_budget := maxi(1, int(raw_range[0]))
	var max_budget := maxi(min_budget, int(raw_range[1]))
	return Vector2i(min_budget, max_budget)


func get_customer_personal_preference_range(_item_id: String) -> Vector2:
	var raw_range: Array = customer_preferences.get("personal_preference_range", [0.2, 0.95])
	if raw_range.size() < 2:
		return Vector2(0.2, 0.95)
	var min_preference := clampf(float(raw_range[0]), 0.0, 1.0)
	var max_preference := clampf(float(raw_range[1]), min_preference, 1.0)
	return Vector2(min_preference, max_preference)


func get_population_config() -> Dictionary:
	return population


func get_flow_preferences_config() -> Dictionary:
	return flow_preferences


func get_calendar_config() -> Dictionary:
	return calendar


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


func _normalized_customer_preferences(raw_preferences: Variant) -> Dictionary:
	var source: Dictionary = raw_preferences if typeof(raw_preferences) == TYPE_DICTIONARY else {}
	var normalized := {}
	var default_preference := clampf(float(customer_preferences.get("default_preference", 0.45)), 0.0, 1.0)
	for item_id in get_customer_preference_items():
		normalized[item_id] = clampf(float(source.get(item_id, default_preference)), 0.0, 1.0)
	return normalized


func _string_array(raw_items: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(raw_items) != TYPE_ARRAY:
		return result
	for item in raw_items:
		var item_id := str(item)
		if not item_id.is_empty():
			result.append(item_id)
	return result


func _load_json(path: String, fallback: Dictionary = {}) -> Dictionary:
	if not FileAccess.file_exists(path):
		_report_config_load_failure(path, "配置文件不存在", fallback)
		return fallback
	var text := FileAccess.get_file_as_string(path)
	var parser := JSON.new()
	var error := parser.parse(text)
	if error != OK:
		_report_config_load_failure(path, "配置文件 JSON 解析失败：%s" % parser.get_error_message(), fallback)
		return fallback
	if typeof(parser.data) != TYPE_DICTIONARY:
		_report_config_load_failure(path, "配置文件顶层必须是 Dictionary", fallback)
		return fallback
	return parser.data


func _report_config_load_failure(path: String, reason: String, fallback: Dictionary) -> void:
	var message := "%s：%s" % [reason, path]
	if not fallback.is_empty():
		push_warning("%s；保留上一份有效配置" % message)
	else:
		push_error(message)
