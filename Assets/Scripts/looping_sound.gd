extends AudioStreamPlayer

@export var start_on_ready := true


func _ready() -> void:
	if not loop_the_stream(stream):
		finished.connect(play)
	if start_on_ready and stream != null:
		play()


static func loop_the_stream(track: AudioStream) -> bool:
	if track == null:
		return false
	if track is AudioStreamWAV:
		var wav := track as AudioStreamWAV
		if wav.loop_end <= wav.loop_begin:
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		return wav.loop_end > wav.loop_begin
	if "loop" in track:
		track.set("loop", true)
		return true
	return false
