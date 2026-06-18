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
	_assert_true(GameplayDebugLog.get_enabled_channels().has("stall"), "日志入口应能列出启用频道")

	GameplayDebugLog.clear_recent_entries()
	GameplayDebugLog.log("stall", "opened", {"spot": "school_gate"})
	var entries := GameplayDebugLog.get_recent_entries()
	_assert_true(entries.size() == 1, "日志入口应保留近期结构化记录")
	_assert_true(str(entries[0].get("channel", "")) == "stall", "结构化日志应记录频道")
	_assert_true(str(entries[0].get("message", "")) == "opened", "结构化日志应记录消息")
	_assert_true(str(entries[0].get("data", {}).get("spot", "")) == "school_gate", "结构化日志应保留数据")

	get_tree().quit()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
