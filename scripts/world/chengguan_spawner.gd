extends Node

const CHENGGUAN_SCENE := preload("res://scenes/chengguan.tscn")

@export var min_wait_seconds := 18.0
@export var max_wait_seconds := 34.0
@export var daily_limit := 3

var _spawned_today := 0
var _rng := RandomNumberGenerator.new()

@onready var timer: Timer = $Timer


func _ready() -> void:
	_rng.randomize()
	timer.timeout.connect(_on_timer_timeout)
	SignalBus.daily_summary_ready.connect(_on_daily_summary_ready)
	_schedule_next()


func _schedule_next() -> void:
	if _spawned_today >= daily_limit:
		return
	timer.wait_time = _rng.randf_range(min_wait_seconds, max_wait_seconds)
	timer.start()


func _on_timer_timeout() -> void:
	if GameState.current_scene != PrototypeConstants.SCENE_TOWN:
		_schedule_next()
		return
	_spawned_today += 1
	var chengguan := CHENGGUAN_SCENE.instantiate()
	var start := Vector2(_rng.randi_range(-560, 560), _rng.randi_range(-250, 300))
	var points: Array[Vector2] = [
		Vector2(_rng.randi_range(-500, 500), _rng.randi_range(-220, 300)),
		Vector2(_rng.randi_range(-500, 500), _rng.randi_range(-220, 300)),
		Vector2(_rng.randi_range(-600, 600), _rng.randi_range(-260, 340)),
	]
	get_parent().add_child(chengguan)
	chengguan.call("setup", start, points)
	_schedule_next()


func _on_daily_summary_ready(_result: Dictionary) -> void:
	_spawned_today = 0
	_schedule_next()
