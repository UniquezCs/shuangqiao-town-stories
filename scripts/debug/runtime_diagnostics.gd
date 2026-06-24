extends Node

signal issue_reported(issue: Dictionary)

const SEVERITY_WARNING := "warning"
const SEVERITY_ERROR := "error"
const MAX_ISSUES := 50
const DISPLAY_ROW_LIMIT := 8
const AUTO_EXPORT_ON_ERROR_SETTING := "debug/runtime_diagnostics/auto_export_on_error"
const AUTO_EXPORT_PATH_SETTING := "debug/runtime_diagnostics/auto_export_path"

var _issues: Array[Dictionary] = []


func _ready() -> void:
	if not ProjectSettings.has_setting(AUTO_EXPORT_ON_ERROR_SETTING):
		ProjectSettings.set_setting(AUTO_EXPORT_ON_ERROR_SETTING, false)
	if not ProjectSettings.has_setting(AUTO_EXPORT_PATH_SETTING):
		ProjectSettings.set_setting(AUTO_EXPORT_PATH_SETTING, "user://runtime_diagnostics.json")


func report_issue(source: String, code: String, message: String, data: Dictionary = {}, severity := SEVERITY_WARNING) -> void:
	var issue := {
		"source": source,
		"code": code,
		"message": message,
		"data": data.duplicate(true),
		"severity": severity,
		"frame": Engine.get_process_frames(),
		"timestamp_msec": Time.get_ticks_msec(),
	}
	_issues.append(issue)
	while _issues.size() > MAX_ISSUES:
		_issues.pop_front()
	issue_reported.emit(issue.duplicate(true))
	if severity == SEVERITY_ERROR and bool(ProjectSettings.get_setting(AUTO_EXPORT_ON_ERROR_SETTING, false)):
		write_log(str(ProjectSettings.get_setting(AUTO_EXPORT_PATH_SETTING, "user://runtime_diagnostics.json")))


func get_issues(source := "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for issue in _issues:
		if source.is_empty() or str(issue.get("source", "")) == source:
			result.append(issue.duplicate(true))
	return result


func get_summary() -> Dictionary:
	var by_source := {}
	var by_severity := {}
	for issue in _issues:
		var source := str(issue.get("source", ""))
		var severity := str(issue.get("severity", ""))
		by_source[source] = int(by_source.get(source, 0)) + 1
		by_severity[severity] = int(by_severity.get(severity, 0)) + 1
	return {
		"total": _issues.size(),
		"by_source": by_source,
		"by_severity": by_severity,
		"latest_issue": _issues.back().duplicate(true) if not _issues.is_empty() else {},
	}


func get_display_rows(limit: int = DISPLAY_ROW_LIMIT) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var start: int = maxi(0, _issues.size() - limit)
	for index in range(start, _issues.size()):
		var issue: Dictionary = _issues[index]
		rows.append({
			"source": str(issue.get("source", "")),
			"code": str(issue.get("code", "")),
			"severity": str(issue.get("severity", "")),
			"message": str(issue.get("message", "")),
			"frame": int(issue.get("frame", 0)),
			"timestamp_msec": int(issue.get("timestamp_msec", 0)),
		})
	return rows


func write_log(path: String = "user://runtime_diagnostics.json") -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var payload := {
		"summary": get_summary(),
		"issues": get_issues(),
	}
	file.store_string(JSON.stringify(payload, "\t"))
	return true


func clear(source := "") -> void:
	if source.is_empty():
		_issues.clear()
		return
	_issues = _issues.filter(func(issue: Dictionary) -> bool:
		return str(issue.get("source", "")) != source
	)
