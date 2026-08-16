extends AudioStreamPlayer

const CRUSH_BUS := &"Crush"

@export var crushing := true : set = set_crushing
@export_range(1, 64, 1) var downsample := 8
@export_range(1, 16, 1) var bit_depth := 16
@export_range(0.02, 0.5, 0.01) var buffer_seconds := 0.1
@export_range(0.05, 4.0, 0.05) var fade_seconds := 0.5

var strength := 1.0

var dropped_frames := 0
var pushed_frames := 0

var _capture: AudioEffectCapture
var _silence_slot := -1
var _playback: AudioStreamGeneratorPlayback
var _hold := Vector2.ZERO
var _countdown := 0
var _mix := 1.0


func _ready() -> void:
	add_to_group("bitcrush")
	install_bus()
	_capture = find_capture()
	_apply_bypass()
	if _capture == null:
		push_warning("bitcrush found no capture effect on the crush bus")
		set_process(false)
		return

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = AudioServer.get_mix_rate()
	generator.buffer_length = buffer_seconds
	stream = generator
	bus = &"Master"
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback

	route_everything(get_tree().root)
	get_tree().node_added.connect(route_one)


func install_bus() -> void:
	if AudioServer.get_bus_index(CRUSH_BUS) >= 0:
		return
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, CRUSH_BUS)
	AudioServer.set_bus_send(index, &"Master")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 0.1
	AudioServer.add_bus_effect(index, capture, 0)
	var silence := AudioEffectAmplify.new()
	silence.volume_db = -80.0
	AudioServer.add_bus_effect(index, silence, 1)
	for other in AudioServer.bus_count:
		if other != index and other != 0 and AudioServer.get_bus_send(other) == &"Master":
			AudioServer.set_bus_send(other, CRUSH_BUS)


func find_capture() -> AudioEffectCapture:
	var index := AudioServer.get_bus_index(CRUSH_BUS)
	if index < 0:
		return null
	var found: AudioEffectCapture = null
	for slot in AudioServer.get_bus_effect_count(index):
		var effect := AudioServer.get_bus_effect(index, slot)
		if effect is AudioEffectCapture:
			found = effect
		elif effect is AudioEffectAmplify:
			_silence_slot = slot
	return found


func set_crushing(on: bool) -> void:
	crushing = on
	_apply_bypass()


func _apply_bypass() -> void:
	if _silence_slot < 0:
		return
	var index := AudioServer.get_bus_index(CRUSH_BUS)
	if index < 0:
		return
	AudioServer.set_bus_effect_enabled(index, _silence_slot, crushing and _capture != null)


func _exit_tree() -> void:
	if _silence_slot >= 0:
		var index := AudioServer.get_bus_index(CRUSH_BUS)
		if index >= 0:
			AudioServer.set_bus_effect_enabled(index, _silence_slot, false)


func route_everything(node: Node) -> void:
	route_one(node)
	for child in node.get_children():
		route_everything(child)


func route_one(node: Node) -> void:
	if node == self:
		return
	if not (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D):
		return
	if node.bus == &"Master":
		node.bus = CRUSH_BUS


func crush(frames: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(frames.size())
	for i in frames.size():
		if _countdown <= 0:
			_countdown = downsample
			_hold = frames[i]
		_countdown -= 1
		out[i] = frames[i].lerp(quantise(_hold), _mix)
	return out


func quantise(frame: Vector2) -> Vector2:
	if bit_depth >= 16:
		return frame
	var levels := float(1 << bit_depth)
	return Vector2(roundf(frame.x * levels) / levels, roundf(frame.y * levels) / levels)


func _process(delta: float) -> void:
	if _capture == null or _playback == null:
		return
	_mix = move_toward(_mix, strength, delta / maxf(fade_seconds, 0.01))
	if not crushing:
		_capture.clear_buffer()
		return
	var waiting := _capture.get_frames_available()
	if waiting <= 0:
		return
	var room := _playback.get_frames_available()
	if room <= 0:
		dropped_frames += waiting
		_capture.clear_buffer()
		return
	var frames := _capture.get_buffer(mini(waiting, room))
	_playback.push_buffer(crush(frames))
	pushed_frames += frames.size()
