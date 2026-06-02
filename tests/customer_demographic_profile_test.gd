extends Node

const CUSTOMER_SCENE := preload("res://scenes/customer.tscn")
const DEMOGRAPHICS := [
	[PrototypeConstants.CUSTOMER_AGE_YOUTH, PrototypeConstants.CUSTOMER_GENDER_MALE],
	[PrototypeConstants.CUSTOMER_AGE_YOUTH, PrototypeConstants.CUSTOMER_GENDER_FEMALE],
	[PrototypeConstants.CUSTOMER_AGE_MIDDLE, PrototypeConstants.CUSTOMER_GENDER_MALE],
	[PrototypeConstants.CUSTOMER_AGE_MIDDLE, PrototypeConstants.CUSTOMER_GENDER_FEMALE],
	[PrototypeConstants.CUSTOMER_AGE_ELDER, PrototypeConstants.CUSTOMER_GENDER_MALE],
	[PrototypeConstants.CUSTOMER_AGE_ELDER, PrototypeConstants.CUSTOMER_GENDER_FEMALE],
]


func _ready() -> void:
	_assert_visual_default_demographics()
	_assert_customer_preference_config_covers_sellable_crops()
	_assert_demographic_profiles_are_distinct_and_blended()
	get_tree().quit()


func _assert_visual_default_demographics() -> void:
	var youth_female := CUSTOMER_SCENE.instantiate()
	youth_female.call("setup", PrototypeConstants.CUSTOMER_STUDENT, null, Vector2.ZERO, Vector2(100, 0), [], PrototypeConstants.CUSTOMER_VISUAL_YOUTH_FEMALE)
	var youth_female_profile: Dictionary = youth_female.call("get_customer_profile")
	_assert_equal(youth_female_profile["age_group"], PrototypeConstants.CUSTOMER_AGE_YOUTH, "少年女性外观应默认绑定少年")
	_assert_equal(youth_female_profile["gender"], PrototypeConstants.CUSTOMER_GENDER_FEMALE, "少年女性外观应默认绑定女性")
	youth_female.queue_free()

	var middle_male := CUSTOMER_SCENE.instantiate()
	middle_male.call("setup", PrototypeConstants.CUSTOMER_WORKER, null, Vector2.ZERO, Vector2(100, 0), [], PrototypeConstants.CUSTOMER_VISUAL_MIDDLE_MALE)
	var middle_male_profile: Dictionary = middle_male.call("get_customer_profile")
	_assert_equal(middle_male_profile["age_group"], PrototypeConstants.CUSTOMER_AGE_MIDDLE, "中年男性外观应默认绑定中年")
	_assert_equal(middle_male_profile["gender"], PrototypeConstants.CUSTOMER_GENDER_MALE, "中年男性外观应默认绑定男性")
	middle_male.queue_free()

	var elder_male := CUSTOMER_SCENE.instantiate()
	elder_male.call("setup", PrototypeConstants.CUSTOMER_WORKER, null, Vector2.ZERO, Vector2(100, 0), [], PrototypeConstants.CUSTOMER_VISUAL_ELDER_MALE)
	var elder_male_profile: Dictionary = elder_male.call("get_customer_profile")
	_assert_equal(elder_male_profile["age_group"], PrototypeConstants.CUSTOMER_AGE_ELDER, "老年男性外观应默认绑定老年")
	_assert_equal(elder_male_profile["gender"], PrototypeConstants.CUSTOMER_GENDER_MALE, "老年男性外观应默认绑定男性")
	elder_male.queue_free()

	var elder := CUSTOMER_SCENE.instantiate()
	elder.call("setup", PrototypeConstants.CUSTOMER_WORKER, null, Vector2.ZERO, Vector2(100, 0), [], PrototypeConstants.CUSTOMER_VISUAL_FEMALE_ELDER)
	var elder_profile: Dictionary = elder.call("get_customer_profile")
	_assert_equal(elder_profile["age_group"], PrototypeConstants.CUSTOMER_AGE_ELDER, "女性老人外观应默认绑定老年")
	_assert_equal(elder_profile["gender"], PrototypeConstants.CUSTOMER_GENDER_FEMALE, "女性老人外观应默认绑定女性")
	elder.queue_free()

	var middle := CUSTOMER_SCENE.instantiate()
	middle.call("setup", PrototypeConstants.CUSTOMER_WORKER, null, Vector2.ZERO, Vector2(100, 0), [], PrototypeConstants.CUSTOMER_VISUAL_FEMALE_MIDDLE)
	var middle_profile: Dictionary = middle.call("get_customer_profile")
	_assert_equal(middle_profile["age_group"], PrototypeConstants.CUSTOMER_AGE_MIDDLE, "女性中年外观应默认绑定中年")
	_assert_equal(middle_profile["gender"], PrototypeConstants.CUSTOMER_GENDER_FEMALE, "女性中年外观应默认绑定女性")
	middle.queue_free()


func _assert_demographic_profiles_are_distinct_and_blended() -> void:
	var signatures := {}
	var profile_items: Array[String] = ConfigLoader.get_customer_preference_items()
	for demographic in DEMOGRAPHICS:
		var customer := CUSTOMER_SCENE.instantiate()
		customer.call("setup", PrototypeConstants.CUSTOMER_STUDENT, null, Vector2.ZERO, Vector2(100, 0), [], "", demographic[0], demographic[1])
		var profile: Dictionary = customer.call("get_customer_profile")
		var base_preferences: Dictionary = profile["base_preferences"]
		var personal_preferences: Dictionary = profile["personal_preferences"]
		var final_preferences: Dictionary = profile["preferences"]
		var base_budget := int(profile["base_budget"])
		var personal_budget := int(profile["personal_budget"])

		_assert_equal(profile["age_group"], demographic[0], "显式年龄应写入顾客画像")
		_assert_equal(profile["gender"], demographic[1], "显式性别应写入顾客画像")
		_assert_equal(int(profile["budget"]), int(round((float(base_budget) + float(personal_budget)) * 0.5)), "最终预算应由基础预算和个体预算各占一半")

		for item_id in profile_items:
			var expected := (float(base_preferences[item_id]) + float(personal_preferences[item_id])) * 0.5
			_assert_almost_equal(float(final_preferences[item_id]), expected, "%s 最终喜好应由基础喜好和个体喜好各占一半" % item_id)

		var signature := "%d|%s" % [base_budget, JSON.stringify(base_preferences)]
		_assert_true(not signatures.has(signature), "每种年龄和性别组合应有不同的基础预算/喜好")
		signatures[signature] = true
		customer.queue_free()


func _assert_customer_preference_config_covers_sellable_crops() -> void:
	var profile_items: Array[String] = ConfigLoader.get_customer_preference_items()
	for item_id in ConfigLoader.items.keys():
		if not ConfigLoader.is_sellable_item(str(item_id)):
			continue
		_assert_true(profile_items.has(str(item_id)), "顾客喜好配置应覆盖可售作物：%s" % str(item_id))

	for demographic in DEMOGRAPHICS:
		var base_profile: Dictionary = ConfigLoader.get_customer_base_profile(demographic[0], demographic[1])
		var preferences: Dictionary = base_profile.get("preferences", {})
		for item_id in profile_items:
			_assert_true(preferences.has(item_id), "%s/%s 基础喜好应包含：%s" % [demographic[0], demographic[1], item_id])


func _assert_almost_equal(actual: float, expected: float, message: String) -> void:
	if abs(actual - expected) > 0.0001:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
