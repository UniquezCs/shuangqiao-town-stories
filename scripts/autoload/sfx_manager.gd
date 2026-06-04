extends Node

const CASH_RECEIVED_PATH := "res://assets/audio/sfx/cash_received.wav"

var sfx_player: AudioStreamPlayer = null


func _ready() -> void:
	_ensure_player()
	var callback := Callable(self, "_on_sale_completed")
	if not SignalBus.sale_completed.is_connected(callback):
		SignalBus.sale_completed.connect(callback)


func play_cash_received() -> void:
	_ensure_player()
	var stream := load(CASH_RECEIVED_PATH)
	if stream == null:
		push_warning("收钱音效资源不存在：%s" % CASH_RECEIVED_PATH)
		return
	sfx_player.stream = stream
	sfx_player.volume_db = -4.0
	if DisplayServer.get_name() == "headless":
		return
	sfx_player.play()


func _ensure_player() -> void:
	if sfx_player != null:
		return
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	sfx_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	sfx_player.max_polyphony = 4
	add_child(sfx_player)


func _on_sale_completed(_item_id: String, _price: int, _remaining_stock: int) -> void:
	play_cash_received()
