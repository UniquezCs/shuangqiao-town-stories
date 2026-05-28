extends Node

const ITEM_APPLE := "apple"
const ITEM_APPLE_SEED := "apple_seed"

const SEED_PRICE := 2
const APPLE_HARVEST_COUNT := 5
const MIN_APPLE_PRICE := 1
const MAX_APPLE_PRICE := 5
const SHOP_APPLE_PRICE_MIN := 1
const SHOP_APPLE_PRICE_MAX := 5
const SHOP_APPLE_STOCK_MIN := 3
const SHOP_APPLE_STOCK_MAX := 12
const STALL_PLAYER_BOUNDARY_HALF_SIZE := 96.0
const STALL_PLAYER_BOUNDARY_WALL_THICKNESS := 16.0
const CUSTOMER_PURCHASE_WAIT_MIN_SECONDS := 5.0
const CUSTOMER_PURCHASE_WAIT_MAX_SECONDS := 10.0

const SCENE_HOME := "home"
const SCENE_TOWN := "town"

const WINDOW_PREP := "prep"
const WINDOW_MORNING := "morning"
const WINDOW_SCHOOL := "school"
const WINDOW_FACTORY := "factory"
const WINDOW_END := "end"

const SPOT_SCHOOL := "school_gate"
const SPOT_FACTORY := "factory_gate"
const SPOT_STREET := "street_stall"
const SPOT_SOUTH_STREET := "south_street"

const CUSTOMER_STUDENT := "student"
const CUSTOMER_WORKER := "worker"

const WINDOW_LABELS := {
	WINDOW_PREP: "准备",
	WINDOW_MORNING: "上午",
	WINDOW_SCHOOL: "放学",
	WINDOW_FACTORY: "下班",
	WINDOW_END: "日终",
}

const ITEM_LABELS := {
	ITEM_APPLE: "苹果",
	ITEM_APPLE_SEED: "苹果种子",
}
