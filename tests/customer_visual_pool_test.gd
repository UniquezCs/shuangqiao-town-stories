extends Node

const CustomerSpawnerScript := preload("res://scripts/world/customer_spawner.gd")
const TownRandomCustomerSpawnerScript := preload("res://scripts/world/town_random_customer_spawner.gd")


func _ready() -> void:
	_assert_commute_visual_pool(
		PrototypeConstants.CUSTOMER_STUDENT,
		PrototypeConstants.STUDENT_CUSTOMER_VISUAL_VARIANTS,
		"学生通勤 NPC 只能从少年男女素材池中随机"
	)
	_assert_commute_visual_pool(
		PrototypeConstants.CUSTOMER_WORKER,
		PrototypeConstants.WORKER_CUSTOMER_VISUAL_VARIANTS,
		"工人通勤 NPC 只能从中年男女素材池中随机"
	)
	_assert_random_town_visual_pool()
	get_tree().quit()


func _assert_commute_visual_pool(customer_type: String, expected_pool: Array, message: String) -> void:
	var spawner := Node.new()
	spawner.set_script(CustomerSpawnerScript)
	spawner.customer_type = customer_type
	for _index in range(24):
		_assert_true(expected_pool.has(spawner.call("_random_visual_variant_for_customer_type")), message)
	spawner.queue_free()


func _assert_random_town_visual_pool() -> void:
	var spawner := Node.new()
	spawner.set_script(TownRandomCustomerSpawnerScript)
	for _index in range(24):
		_assert_true(
			PrototypeConstants.RANDOM_CUSTOMER_VISUAL_VARIANTS.has(spawner.call("_random_visual_variant")),
			"随机路人 NPC 只能从老年男女素材池中随机"
		)
	spawner.queue_free()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
