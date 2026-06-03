extends Node

const DEFAULT_BGM_PATH := "res://assets/audio/bgm/shuangqiao_town_loop.wav"

var bgm_player: AudioStreamPlayer = null


func _ready() -> void:
	_ensure_player()
	play_default_bgm()


func play_default_bgm() -> void:
	play_bgm(DEFAULT_BGM_PATH)


func play_bgm(stream_path: String) -> void:
	_ensure_player()
	if bgm_player.playing and bgm_player.stream != null and bgm_player.stream.resource_path == stream_path:
		return
	var stream := load(stream_path)
	if stream == null:
		push_warning("BGM 资源不存在：%s" % stream_path)
		return
	_configure_loop(stream)
	bgm_player.stream = stream
	bgm_player.volume_db = -12.0
	if DisplayServer.get_name() == "headless":
		return
	bgm_player.play()


func stop_bgm() -> void:
	if bgm_player != null:
		bgm_player.stop()
		bgm_player.stream = null


func is_playing() -> bool:
	return bgm_player != null and bgm_player.playing


func _ensure_player() -> void:
	if bgm_player != null:
		return
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.bus = "Master"
	add_child(bgm_player)


func _configure_loop(stream: AudioStream) -> void:
	_set_stream_property(stream, "loop_mode", 1)
	_set_stream_property(stream, "loop_begin", 0)
	if stream.has_method("get_length"):
		var length_samples := int(stream.get_length() * float(_get_stream_property(stream, "mix_rate", 44100)))
		if length_samples > 0:
			_set_stream_property(stream, "loop_end", length_samples)


func _set_stream_property(stream: AudioStream, property_name: String, value: Variant) -> void:
	for property in stream.get_property_list():
		if str(property.get("name", "")) == property_name:
			stream.set(property_name, value)
			return


func _get_stream_property(stream: AudioStream, property_name: String, fallback: Variant) -> Variant:
	for property in stream.get_property_list():
		if str(property.get("name", "")) == property_name:
			return stream.get(property_name)
	return fallback
