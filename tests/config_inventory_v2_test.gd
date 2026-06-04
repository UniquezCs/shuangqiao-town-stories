extends Node


func _ready() -> void:
	GameState.reset_game()
	_assert_equal(Inventory.get_count(PrototypeConstants.ITEM_APPLE), 1, "新游戏初始应给玩家 1 个苹果")
	_assert_equal(Inventory.get_count(PrototypeConstants.ITEM_PEAR), 1, "新游戏初始应给玩家 1 个梨")
	_assert_equal(ConfigLoader.get_item_name(PrototypeConstants.ITEM_APPLE), "苹果", "应能读取商品配置名称")
	_assert_equal(ConfigLoader.get_stack_size(PrototypeConstants.ITEM_APPLE), 20, "应能读取商品堆叠上限")
	_assert_true(ConfigLoader.get_seed_shop_seed_items().has("pear_seed"), "种子商店应包含梨种子")
	_assert_true(ConfigLoader.get_seed_shop_seed_items().has("banana_seed"), "种子商店应包含香蕉种子")
	_assert_true(ConfigLoader.get_seed_shop_seed_items().has("grape_seed"), "种子商店应包含葡萄种子")
	_assert_true(ResourceLoader.exists(ConfigLoader.get_crop_state_texture("pear", "ready")), "梨成熟状态素材应可加载")
	_assert_true(ResourceLoader.exists(ConfigLoader.get_crop_state_texture("banana", "ready")), "香蕉成熟状态素材应可加载")
	_assert_true(ResourceLoader.exists(ConfigLoader.get_crop_state_texture("grape", "ready")), "葡萄成熟状态素材应可加载")
	_assert_true(ResourceLoader.exists(ConfigLoader.get_item_icon(PrototypeConstants.ITEM_WATERING_CAN)), "水壶图标素材应可加载")
	_assert_true(ResourceLoader.exists(ConfigLoader.get_item_icon(PrototypeConstants.ITEM_HOE)), "锄头图标素材应可加载")
	_assert_true(ResourceLoader.exists(ConfigLoader.get_item_icon(PrototypeConstants.ITEM_SICKLE)), "镰刀图标素材应可加载")
	_assert_equal(ConfigLoader.get_tool_for_item(PrototypeConstants.ITEM_WATERING_CAN), PrototypeConstants.TOOL_WATER, "水壶物品应映射到浇水工具")
	_assert_true(not ConfigLoader.get_asset("character.vendor").is_empty(), "应能读取资源注册表中的主角资源")
	_assert_equal(
		ConfigLoader.get_asset_path("tileset.rural_town_32"),
		"res://assets/generated/tilesets/rural_town_32/rural_town_tileset_32.tres",
		"应能通过资源 ID 读取资源路径"
	)

	Inventory.set_count(PrototypeConstants.ITEM_APPLE_SEED, 0)
	Inventory.set_count(PrototypeConstants.ITEM_APPLE, 0)
	Inventory.set_count(PrototypeConstants.ITEM_PEAR, 0)
	Inventory.configure_slot_count(1)
	_assert_true(Inventory.add_item(PrototypeConstants.ITEM_APPLE, 20), "一个格子应能装满一组苹果")
	_assert_true(not Inventory.add_item(PrototypeConstants.ITEM_APPLE, 1), "背包满时应拒绝新增物品")
	_assert_equal(Inventory.get_count(PrototypeConstants.ITEM_APPLE), 20, "满包失败不应偷偷增加物品")

	Inventory.configure_slot_count(2)
	_assert_true(Inventory.add_item(PrototypeConstants.ITEM_APPLE, 1), "升级背包容量后应能继续装物品")
	_assert_equal(Inventory.get_count(PrototypeConstants.ITEM_APPLE), 21, "升级后苹果总数应正确")
	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
