extends RefCounted

const EVENT_SEE_STALL := "see_stall"
const EVENT_WAITING := "waiting"
const EVENT_BUDGET_REJECT := "budget_reject"
const EVENT_PRICE_REJECT := "price_reject"
const EVENT_NO_INTEREST := "no_interest"
const EVENT_PURCHASED := "purchased"
const EVENT_TIMEOUT := "timeout"
const EVENT_STALL_CLOSED := "stall_closed"

const EVENT_CHANCES := {
	EVENT_SEE_STALL: 0.35,
	EVENT_WAITING: 0.55,
	EVENT_BUDGET_REJECT: 0.65,
	EVENT_PRICE_REJECT: 0.60,
	EVENT_NO_INTEREST: 0.25,
	EVENT_PURCHASED: 0.70,
	EVENT_TIMEOUT: 0.45,
	EVENT_STALL_CLOSED: 0.50,
}

const COMMON_LINES := {
	EVENT_SEE_STALL: [
		"这{item}摆出来挺新鲜。",
		"老板，{item}怎么卖？",
		"路边摊也有{item}了？",
		"先看看，合适就买点{item}。",
	],
	EVENT_WAITING: [
		"{item}{price}块钱？我想想。",
		"这{item}看着不错，给我留一下。",
		"老板，称一份{item}吧。",
		"{item}要是新鲜，我就买一份。",
	],
	EVENT_BUDGET_REJECT: [
		"兜里钱不够，今天先算了。",
		"{item}是好，就是钱没带够。",
		"预算紧，买不起这个价。",
		"等发了钱再来看看。",
	],
	EVENT_PRICE_REJECT: [
		"卖这么贵啊。",
		"{item}这个价有点高。",
		"镇上别家好像便宜点。",
		"老板，便宜点我就买。",
	],
	EVENT_NO_INTEREST: [
		"今天不想买{item}。",
		"家里还有，不添了。",
		"先转转，等会儿再说。",
		"这会儿用不上{item}。",
	],
	EVENT_PURCHASED: [
		"谢谢老板，拿回去尝尝。",
		"行，就要这份{item}。",
		"给你钱，老板收好。",
		"这{item}看着实在，下次再来。",
	],
	EVENT_TIMEOUT: [
		"等太久了，我先走了。",
		"老板忙着呢？下回吧。",
		"算了，赶时间。",
		"没人招呼，我去别处看看。",
	],
	EVENT_STALL_CLOSED: [
		"怎么收摊了？那下次吧。",
		"来晚一步。",
		"老板要走了？那不买了。",
	],
}

const AGE_LINES := {
	PrototypeConstants.CUSTOMER_AGE_YOUTH: {
		EVENT_SEE_STALL: [
			"放学路上买点{item}也行。",
			"{item}看着挺甜的。",
			"我就剩几块钱，先问问价。",
		],
		EVENT_PRICE_REJECT: [
			"太贵了，我零花钱不够。",
			"这个价我得攒两天。",
			"老板，学生便宜点吧。",
		],
		EVENT_PURCHASED: [
			"谢谢老板，边走边吃。",
			"这份{item}我带回学校。",
			"老板给我挑个好点的。",
		],
	},
	PrototypeConstants.CUSTOMER_AGE_MIDDLE: {
		EVENT_SEE_STALL: [
			"下班路上顺手买点{item}。",
			"家里正好缺点{item}。",
			"看着还成，问问价。",
		],
		EVENT_PRICE_REJECT: [
			"日子紧，这价不好下手。",
			"老板，街坊价给低点。",
			"这个价买回去不好交代。",
		],
		EVENT_PURCHASED: [
			"行，今晚家里添个菜。",
			"谢谢老板，做生意不容易。",
			"给我装好点，回家就用。",
		],
	},
	PrototypeConstants.CUSTOMER_AGE_ELDER: {
		EVENT_SEE_STALL: [
			"这{item}看着还算新鲜。",
			"买菜还是得多看两眼。",
			"老板，{item}别缺斤少两啊。",
		],
		EVENT_PRICE_REJECT: [
			"贵了贵了，省着点过日子。",
			"这个价不如明早赶集。",
			"我再往前看看。",
		],
		EVENT_PURCHASED: [
			"钱给你，慢慢做生意。",
			"这{item}拿回去够吃一顿。",
			"老板人实在，下回还来。",
		],
	},
}

const GENDER_LINES := {
	PrototypeConstants.CUSTOMER_GENDER_FEMALE: {
		EVENT_WAITING: [
			"我挑挑{item}，别太蔫。",
			"老板，给我装新鲜点的。",
			"{item}要好，家里孩子要吃。",
		],
	},
	PrototypeConstants.CUSTOMER_GENDER_MALE: {
		EVENT_WAITING: [
			"老板，快点称，我还赶路。",
			"就这{item}吧，别少称。",
			"看着顺眼，来一份。",
		],
	},
}

const ITEM_LINES := {
	"apple": {
		EVENT_SEE_STALL: [
			"这苹果红是红，不知道脆不脆。",
			"苹果看着不错，给孩子带一个。",
		],
	},
	"pear": {
		EVENT_SEE_STALL: [
			"梨看着水灵，多少钱？",
			"天热了，买个梨润润。",
		],
	},
	"cabbage": {
		EVENT_SEE_STALL: [
			"白菜要是便宜，晚上炖一锅。",
			"这白菜帮子挺厚实。",
		],
	},
	"cucumber": {
		EVENT_SEE_STALL: [
			"黄瓜看着脆，凉拌正好。",
			"这黄瓜别是蔫的吧。",
		],
	},
	"tomato": {
		EVENT_SEE_STALL: [
			"番茄红得挺正。",
			"番茄炒蛋能用上。",
		],
	},
	"potato": {
		EVENT_SEE_STALL: [
			"土豆耐放，便宜就买点。",
			"这土豆个头还行。",
		],
	},
	"banana": {
		EVENT_PRICE_REJECT: [
			"香蕉在镇上卖这个价，舍不得。",
			"香蕉是稀罕，可太贵了。",
		],
	},
	"grape": {
		EVENT_PRICE_REJECT: [
			"葡萄好是好，价格也是真高。",
			"葡萄买一串就顶一天菜钱了。",
		],
	},
}


static func line_for(event: String, profile: Dictionary, item_id: String, price: int, reason: String, rng: RandomNumberGenerator) -> String:
	var candidates: Array[String] = []
	_append_lines(candidates, COMMON_LINES.get(event, []))
	var age_group := str(profile.get("age_group", ""))
	var gender := str(profile.get("gender", ""))
	var age_events: Dictionary = AGE_LINES.get(age_group, {})
	var gender_events: Dictionary = GENDER_LINES.get(gender, {})
	var item_events: Dictionary = ITEM_LINES.get(item_id, {})
	_append_lines(candidates, age_events.get(event, []))
	_append_lines(candidates, gender_events.get(event, []))
	_append_lines(candidates, item_events.get(event, []))
	if candidates.is_empty():
		candidates.append(reason if not reason.is_empty() else "先看看。")
	var template := candidates[rng.randi_range(0, candidates.size() - 1)]
	return _format_line(template, item_id, price)


static func trigger_chance_for(event: String) -> float:
	return clampf(float(EVENT_CHANCES.get(event, 0.5)), 0.0, 1.0)


static func _append_lines(target: Array[String], source: Variant) -> void:
	if typeof(source) != TYPE_ARRAY:
		return
	for line in source:
		target.append(str(line))


static func _format_line(template: String, item_id: String, price: int) -> String:
	var item_name := ConfigLoader.get_item_name(item_id)
	if item_name.is_empty():
		item_name = item_id
	return template.replace("{item}", item_name).replace("{price}", str(price))
