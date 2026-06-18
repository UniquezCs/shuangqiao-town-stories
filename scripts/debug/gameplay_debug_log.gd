extends RefCounted

const ENABLED_SETTING := "debug/gameplay/economy_and_patrol_logs_enabled"
const CHANNEL_SETTING_PREFIX := "debug/gameplay/log_channels"
const CHANNELS := ["chengguan", "customer", "patrol", "population_flow", "stall"]
const MAX_RECENT_ENTRIES := 100

static var _recent_entries: Array[Dictionary] = []


static func channel_setting(channel: String) -> String:
	return "%s/%s_enabled" % [CHANNEL_SETTING_PREFIX, channel]


static func is_enabled(channel := "") -> bool:
	if not bool(ProjectSettings.get_setting(ENABLED_SETTING, false)):
		return false
	if channel.is_empty():
		return true
	var setting := channel_setting(channel)
	return bool(ProjectSettings.get_setting(setting, true))


static func get_enabled_channels() -> Array[String]:
	var result: Array[String] = []
	for channel in CHANNELS:
		if is_enabled(channel):
			result.append(channel)
	return result


static func log(channel: String, message: String, data: Dictionary = {}) -> void:
	if not is_enabled(channel):
		return
	_remember_entry(channel, message, data)
	var suffix := ""
	if not data.is_empty():
		suffix = " %s" % JSON.stringify(data)
	print("[gameplay:%s] %s%s" % [channel, message, suffix])


static func get_recent_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _recent_entries:
		result.append(entry.duplicate(true))
	return result


static func clear_recent_entries() -> void:
	_recent_entries.clear()


static func _remember_entry(channel: String, message: String, data: Dictionary) -> void:
	_recent_entries.append({
		"channel": channel,
		"message": message,
		"data": data.duplicate(true),
		"frame": Engine.get_process_frames(),
		"timestamp_msec": Time.get_ticks_msec(),
	})
	while _recent_entries.size() > MAX_RECENT_ENTRIES:
		_recent_entries.pop_front()
