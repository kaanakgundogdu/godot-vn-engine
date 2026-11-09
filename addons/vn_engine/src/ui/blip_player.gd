class_name VNEngineBlipPlayer
extends AudioStreamPlayer

signal blipped(pitch: float)

const MIX_RATE: int = 22050
const LENGTH: float = 0.04
const FREQUENCY: float = 440.0
const ATTACK: float = 0.003
const LEVEL: float = 0.3

static var _generated: AudioStreamWAV

var blip_count: int = 0


func _ready() -> void:
	bus = "Sfx"
	max_polyphony = 3


func blip(sound: AudioStream, pitch: float) -> void:
	stream = sound if sound != null else _generated_sound()
	pitch_scale = pitch * randf_range(0.95, 1.05)
	play()
	blip_count += 1
	blipped.emit(pitch_scale)


static func _generated_sound() -> AudioStreamWAV:
	if _generated != null:
		return _generated
	var frames: int = int(MIX_RATE * LENGTH)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var period: float = MIX_RATE / FREQUENCY
	for i in frames:
		var time: float = float(i) / MIX_RATE
		var wave: float = 1.0 if fmod(i, period) < period * 0.5 else -1.0
		var envelope: float = minf(time / ATTACK, 1.0) * exp(-time * 70.0)
		data.encode_s16(i * 2, int(wave * envelope * LEVEL * 32767.0))
	_generated = AudioStreamWAV.new()
	_generated.format = AudioStreamWAV.FORMAT_16_BITS
	_generated.mix_rate = MIX_RATE
	_generated.data = data
	return _generated
