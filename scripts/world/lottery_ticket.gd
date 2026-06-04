extends Node

const TICKET_PRICE := 10
const DIGIT_MIN := 0
const DIGIT_MAX := 9
const ROLL_MAX := 1000

const TIER_NONE := "none"
const TIER_CONSOLATION := "consolation"
const TIER_THIRD := "third"
const TIER_SECOND := "second"
const TIER_JACKPOT := "jackpot"

const TIER_LABELS := {
	TIER_NONE: "未中奖",
	TIER_CONSOLATION: "安慰奖",
	TIER_THIRD: "三等奖",
	TIER_SECOND: "二等奖",
	TIER_JACKPOT: "大奖",
}


func get_ticket() -> Dictionary:
	return GameState.lottery_ticket.duplicate(true)


func has_active_ticket() -> bool:
	return not GameState.lottery_ticket.is_empty()


func can_buy_ticket() -> bool:
	if GameState.cash < TICKET_PRICE:
		return false
	if GameState.lottery_ticket.is_empty():
		return true
	var status := str(GameState.lottery_ticket.get("status", ""))
	return status == "" or status == "closed"


func buy_ticket(digits: Array) -> bool:
	if not _digits_are_valid(digits):
		SignalBus.sale_feedback.emit("号码要选 3 个 0-9 的数字", _feedback_position())
		return false
	if not GameState.lottery_ticket.is_empty():
		SignalBus.sale_feedback.emit("今天已经有一张彩票了", _feedback_position())
		return false
	if not GameState.spend_cash(TICKET_PRICE):
		SignalBus.sale_feedback.emit("钱不够买彩票", _feedback_position())
		return false

	var normalized_digits := _normalized_digits(digits)
	GameState.lottery_ticket = {
		"status": "pending",
		"purchase_day": GameState.day_index,
		"draw_day": GameState.day_index + 1,
		"digits": normalized_digits,
		"selected_number": _digits_to_number(normalized_digits),
		"draw_number": -1,
		"tier": TIER_NONE,
		"prize": 0,
		"claimed": false,
	}
	SignalBus.lottery_ticket_changed.emit(GameState.lottery_ticket.duplicate(true))
	SignalBus.sale_feedback.emit("买了一张 %s，明天开奖" % format_digits(normalized_digits), _feedback_position())
	return true


func resolve_pending_if_due(rng: RandomNumberGenerator = null) -> Dictionary:
	if not _is_pending_due():
		return get_ticket()
	var active_rng := rng
	if active_rng == null:
		active_rng = RandomNumberGenerator.new()
		active_rng.randomize()
	return resolve_pending_with_roll(active_rng.randi_range(1, ROLL_MAX), active_rng.randi_range(0, 999))


func resolve_pending_with_roll(roll: int, candidate_draw_number: int = -1) -> Dictionary:
	if not _is_pending_due():
		return get_ticket()
	var safe_roll := clampi(roll, 1, ROLL_MAX)
	var tier := _tier_for_roll(safe_roll)
	var prize := _prize_for_tier(tier)
	var selected_number := int(GameState.lottery_ticket.get("selected_number", 0))
	var draw_number := selected_number if tier == TIER_JACKPOT else _non_matching_draw_number(selected_number, candidate_draw_number)

	GameState.lottery_ticket["status"] = "drawn"
	GameState.lottery_ticket["draw_number"] = draw_number
	GameState.lottery_ticket["tier"] = tier
	GameState.lottery_ticket["prize"] = prize
	GameState.lottery_ticket["claimed"] = false
	SignalBus.lottery_ticket_changed.emit(GameState.lottery_ticket.duplicate(true))
	return get_ticket()


func claim_or_close_result() -> bool:
	resolve_pending_if_due()
	if GameState.lottery_ticket.is_empty():
		SignalBus.sale_feedback.emit("还没买过彩票", _feedback_position())
		return false
	if str(GameState.lottery_ticket.get("status", "")) != "drawn":
		SignalBus.sale_feedback.emit("还没开奖，明天再来", _feedback_position())
		return false

	var prize := int(GameState.lottery_ticket.get("prize", 0))
	if prize > 0:
		GameState.add_cash(prize)
		SignalBus.sale_feedback.emit("兑奖拿到 %d 元" % prize, _feedback_position())
	else:
		SignalBus.sale_feedback.emit("这张没中，下次再说", _feedback_position())
	GameState.lottery_ticket = {}
	SignalBus.lottery_ticket_changed.emit({})
	return true


func get_status_text() -> String:
	resolve_pending_if_due()
	if GameState.lottery_ticket.is_empty():
		return "今日彩票：10 元一张，选 3 个数字，明天开奖。"

	var ticket: Dictionary = GameState.lottery_ticket
	var digits: Array = ticket.get("digits", [])
	var selected_text: String = format_digits(digits)
	if str(ticket.get("status", "")) == "pending":
		return "已买 %s，第 %d 天开奖。" % [selected_text, int(ticket.get("draw_day", GameState.day_index + 1))]

	var prize := int(ticket.get("prize", 0))
	var tier := str(ticket.get("tier", TIER_NONE))
	var draw_text := format_number(int(ticket.get("draw_number", 0)))
	if prize > 0:
		return "你的号码 %s，开奖号码 %s，中了%s %d 元。" % [selected_text, draw_text, tier_label(tier), prize]
	return "你的号码 %s，开奖号码 %s，没中。" % [selected_text, draw_text]


func get_prompt_text() -> String:
	resolve_pending_if_due()
	if GameState.lottery_ticket.is_empty():
		return "彩票店：买一张彩票（10 元）"
	var status := str(GameState.lottery_ticket.get("status", ""))
	if status == "pending":
		return "彩票店：已买 %s，明天开奖" % format_digits(GameState.lottery_ticket.get("digits", []))
	var prize := int(GameState.lottery_ticket.get("prize", 0))
	if prize > 0:
		return "彩票店：中奖 %d 元，按 E 兑奖" % prize
	return "彩票店：按 E 查看开奖结果"


func tier_label(tier: String) -> String:
	return str(TIER_LABELS.get(tier, "未中奖"))


func format_digits(digits: Array) -> String:
	var normalized_digits := _normalized_digits(digits)
	return "%d%d%d" % [normalized_digits[0], normalized_digits[1], normalized_digits[2]]


func format_number(number: int) -> String:
	var safe_number := clampi(number, 0, 999)
	return "%03d" % safe_number


func _is_pending_due() -> bool:
	return (
		not GameState.lottery_ticket.is_empty()
		and str(GameState.lottery_ticket.get("status", "")) == "pending"
		and GameState.day_index >= int(GameState.lottery_ticket.get("draw_day", GameState.day_index + 1))
	)


func _digits_are_valid(digits: Array) -> bool:
	if digits.size() != 3:
		return false
	for digit in digits:
		var value := int(digit)
		if value < DIGIT_MIN or value > DIGIT_MAX:
			return false
	return true


func _normalized_digits(digits: Array) -> Array:
	var normalized := [0, 0, 0]
	for index in range(mini(3, digits.size())):
		normalized[index] = clampi(int(digits[index]), DIGIT_MIN, DIGIT_MAX)
	return normalized


func _digits_to_number(digits: Array) -> int:
	var normalized_digits := _normalized_digits(digits)
	return normalized_digits[0] * 100 + normalized_digits[1] * 10 + normalized_digits[2]


func _tier_for_roll(roll: int) -> String:
	if roll == 1:
		return TIER_JACKPOT
	if roll <= 51:
		return TIER_SECOND
	if roll <= 151:
		return TIER_THIRD
	if roll <= 351:
		return TIER_CONSOLATION
	return TIER_NONE


func _prize_for_tier(tier: String) -> int:
	match tier:
		TIER_JACKPOT:
			return 10000
		TIER_SECOND:
			return 500
		TIER_THIRD:
			return 50
		TIER_CONSOLATION:
			return 20
	return 0


func _non_matching_draw_number(selected_number: int, candidate_draw_number: int) -> int:
	var draw_number := candidate_draw_number
	if draw_number < 0:
		draw_number = randi_range(0, 999)
	draw_number = clampi(draw_number, 0, 999)
	if draw_number == selected_number:
		draw_number = (draw_number + 1) % 1000
	return draw_number


func _feedback_position() -> Vector2:
	var parent_2d := get_parent() as Node2D
	if parent_2d != null:
		return parent_2d.global_position
	return Vector2.ZERO
