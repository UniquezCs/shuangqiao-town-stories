extends Node

const SeedShop := preload("res://scripts/world/seed_shop.gd")


func _ready() -> void:
	GameState.reset_game()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260528
	GameState.refresh_seed_shop_goods(rng)

	_assert_true(
		GameState.seed_shop_apple_price >= PrototypeConstants.SHOP_APPLE_PRICE_MIN
		and GameState.seed_shop_apple_price <= PrototypeConstants.SHOP_APPLE_PRICE_MAX,
		"每日苹果进价应在 1-5 元之间"
	)
	_assert_true(
		GameState.seed_shop_apple_stock >= PrototypeConstants.SHOP_APPLE_STOCK_MIN
		and GameState.seed_shop_apple_stock <= PrototypeConstants.SHOP_APPLE_STOCK_MAX,
		"每日苹果库存应在配置范围内"
	)

	var shop := SeedShop.new()
	add_child(shop)
	GameState.cash = (
		ConfigLoader.get_seed_price("pear_seed")
		+ ConfigLoader.get_seed_price("banana_seed")
		+ ConfigLoader.get_seed_price("grape_seed")
	)
	_assert_true(shop.buy_seed("pear_seed"), "现金足够时应能买梨种子")
	_assert_true(shop.buy_seed("banana_seed"), "现金足够时应能买香蕉种子")
	_assert_true(shop.buy_seed("grape_seed"), "现金足够时应能买葡萄种子")
	_assert_equal(Inventory.get_count("pear_seed"), 1, "买梨种子后背包应增加")
	_assert_equal(Inventory.get_count("banana_seed"), 1, "买香蕉种子后背包应增加")
	_assert_equal(Inventory.get_count("grape_seed"), 1, "买葡萄种子后背包应增加")
	_assert_equal(GameState.cash, 0, "买完三种新增种子后现金应正确扣完")

	GameState.cash = GameState.seed_shop_apple_price
	var starting_stock: int = GameState.seed_shop_apple_stock
	_assert_true(shop.buy_apple(), "现金足够且有库存时应能直接买苹果")
	_assert_equal(Inventory.get_count(PrototypeConstants.ITEM_APPLE), 1, "买苹果后背包苹果应增加")
	_assert_equal(GameState.cash, 0, "买苹果后应扣除今日苹果进价")
	_assert_equal(GameState.seed_shop_apple_stock, starting_stock - 1, "买苹果后商店库存应减少")

	GameState.cash = 0
	_assert_true(not shop.buy_apple(), "现金不足时不能买苹果")
	GameState.seed_shop_apple_stock = 0
	GameState.cash = PrototypeConstants.SHOP_APPLE_PRICE_MAX
	_assert_true(not shop.buy_apple(), "库存为 0 时不能买苹果")

	shop.queue_free()
	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
