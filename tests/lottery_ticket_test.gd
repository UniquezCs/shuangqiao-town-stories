extends Node

const LotteryTicketScript := preload("res://scripts/world/lottery_ticket.gd")


func _ready() -> void:
	GameState.reset_game()
	GameState.cash = 10
	SignalBus.cash_changed.emit(GameState.cash)

	var ticket := LotteryTicketScript.new()
	add_child(ticket)

	_assert_true(ticket.buy_ticket([1, 2, 3]), "现金足够时应能买一张彩票")
	_assert_equal(GameState.cash, 0, "购票后应扣除 10 元")
	_assert_equal(GameState.lottery_ticket.get("status", ""), "pending", "购票后应进入待开奖状态")
	_assert_equal(GameState.lottery_ticket.get("purchase_day", 0), 1, "购票日应记录为当天")
	_assert_equal(GameState.lottery_ticket.get("draw_day", 0), 2, "开奖日应记录为第二天")
	_assert_equal(ticket.format_digits(GameState.lottery_ticket.get("digits", [])), "123", "应记录玩家选择的三位号码")

	GameState.cash = 10
	_assert_true(not ticket.buy_ticket([4, 5, 6]), "持有待开奖彩票时不能再买第二张")
	_assert_equal(GameState.cash, 10, "重复购票失败时不应扣钱")

	GameState.day_index = 2
	var result := ticket.resolve_pending_with_roll(1, 999)
	_assert_equal(result.get("status", ""), "drawn", "第二天应能开奖")
	_assert_equal(result.get("tier", ""), ticket.TIER_JACKPOT, "roll=1 应命中大奖")
	_assert_equal(result.get("prize", 0), 10000, "大奖奖金应为 10000")
	_assert_equal(result.get("draw_number", -1), 123, "中大奖时开奖号码应匹配玩家号码")

	_assert_true(ticket.claim_or_close_result(), "开奖后应能兑奖")
	_assert_equal(GameState.cash, 10010, "兑奖后应把奖金加入现金")
	_assert_true(GameState.lottery_ticket.is_empty(), "兑奖后应清除旧彩票，允许后续再买")

	GameState.cash = 10
	_assert_true(ticket.buy_ticket([0, 0, 7]), "兑奖后应能再次购票")
	var saved := GameState.to_save_data()
	GameState.reset_game()
	GameState.apply_save_data(saved)
	_assert_equal(ticket.format_digits(GameState.lottery_ticket.get("digits", [])), "007", "彩票状态应进入存档并可恢复")

	GameState.day_index = 3
	result = ticket.resolve_pending_with_roll(352, 7)
	_assert_equal(result.get("tier", ""), ticket.TIER_NONE, "roll=352 应未中奖")
	_assert_equal(result.get("prize", -1), 0, "未中奖奖金应为 0")
	_assert_true(ticket.claim_or_close_result(), "未中奖彩票也应能收起结果")
	_assert_true(GameState.lottery_ticket.is_empty(), "收起未中奖结果后应清除彩票")

	ticket.queue_free()
	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
