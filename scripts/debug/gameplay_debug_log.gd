extends RefCounted

const ENABLED_SETTING := "debug/gameplay/economy_and_patrol_logs_enabled"
const CHANNEL_SETTING_PREFIX := "debug/gameplay/log_channels"


static func channel_setting(channel: String) -> String:
	return "%s/%s_enabled" % [CHANNEL_SETTING_PREFIX, channel]


static func is_enabled(channel := "") -> bool:
	if not bool(ProjectSettings.get_setting(ENABLED_SETTING, false)):
		return false
	if channel.is_empty():
		return true
	var setting := channel_setting(channel)
	return bool(ProjectSettings.get_setting(setting, true))


static func log(channel: String, message: String, data: Dictionary = {}) -> void:
	if not is_enabled(channel):
		return
	var suffix := ""
	if not data.is_empty():
		suffix = " %s" % JSON.stringify(data)
	print("[gameplay:%s] %s%s" % [channel, message, suffix])
