extends RefCounted

const ENABLED_SETTING := "debug/gameplay/economy_and_patrol_logs_enabled"


static func is_enabled() -> bool:
	return bool(ProjectSettings.get_setting(ENABLED_SETTING, false))


static func log(channel: String, message: String, data: Dictionary = {}) -> void:
	if not is_enabled():
		return
	var suffix := ""
	if not data.is_empty():
		suffix = " %s" % JSON.stringify(data)
	print("[gameplay:%s] %s%s" % [channel, message, suffix])
