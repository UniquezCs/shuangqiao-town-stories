extends Node

const GameplayDebugLog := preload("res://scripts/debug/gameplay_debug_log.gd")


func _ready() -> void:
	ProjectSettings.set_setting(GameplayDebugLog.ENABLED_SETTING, false)
	ProjectSettings.set_setting(GameplayDebugLog.channel_setting("population_flow"), true)
	_assert_true(not GameplayDebugLog.is_enabled("population_flow"), "总开关关闭时频道开关不应单独放开日志")

	ProjectSettings.set_setting(GameplayDebugLog.ENABLED_SETTING, true)
	ProjectSettings.set_setting(GameplayDebugLog.channel_setting("population_flow"), false)
	ProjectSettings.set_setting(GameplayDebugLog.channel_setting("stall"), true)
	_assert_true(not GameplayDebugLog.is_enabled("population_flow"), "频道开关关闭时应屏蔽对应日志")
	_assert_true(GameplayDebugLog.is_enabled("stall"), "频道开关打开时应允许对应日志")
	_assert_true(GameplayDebugLog.is_enabled("unknown_channel"), "未配置频道应沿用总开关，保持旧调用兼容")

	get_tree().quit()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
