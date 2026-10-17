class_name GameAudio
extends Node
## Audio del juego:
##  - Música de fondo: "The Kickflip | Roadster" en bucle, en el bus "Music".
##    Un filtro paso-bajo se abre con la velocidad: parado suena apagada, a fondo suena completa.
##  - Efectos de cohete SINTETIZADOS en tiempo real (AudioStreamGenerator), en el bus "SFX":
##      * siseo de gas frío  -> ruido blanco filtrado, sigue a los thrusters verticales y laterales
##      * rugido principal   -> ruido "marrón" grave, sigue a los traseros
##        (el boost lo hace más agudo)
##      * ventilador succión -> zumbido que sube de tono con la fuerza de succión
##    Se sintetizan porque la pista es música, no trae efectos aislados.

const MUSIC_PATH := "res://assets/audio/roadster_kickflip.mp3"
const MIX_RATE := 22050.0

@export var music_volume_db := -6.0  ## música en la portada
## música durante el juego (más baja para oír los cohetes)
@export var music_volume_game_db := -16.0
@export var sfx_volume_db := -4.0

var car: TeslaCar
## En la portada: música a pleno brillo y un siseo/rugido suave de fondo.
## Al empezar, un golpe de cohete marca el arranque.
var intro := true

var _music: AudioStreamPlayer
var _music_lpf: AudioEffectLowPassFilter
var _sfx: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback

# Estado del sintetizador
var _hiss_gain := 0.0
var _rumble_gain := 0.0
var _fan_gain := 0.0
var _fan_freq := 120.0
var _rumble_tone := 0.0
var _hp_prev_in := 0.0
var _hp_prev_out := 0.0
var _brown := 0.0
var _rumble_lp := 0.0
var _fan_phase := 0.0
var _puff := 0.0
var _rcs_was_on := false
var _start_boost := 0.0


func _ready() -> void:
	var music_bus := _ensure_bus("Music")
	_ensure_bus("SFX")
	_music_lpf = AudioEffectLowPassFilter.new()
	_music_lpf.cutoff_hz = 900.0
	AudioServer.add_bus_effect(music_bus, _music_lpf)

	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = music_volume_db
	var stream := load(MUSIC_PATH)
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
		_music.stream = stream
		add_child(_music)
		_music.play()
	else:
		push_warning("No se encontró la música en " + MUSIC_PATH)

	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.1
	_sfx = AudioStreamPlayer.new()
	_sfx.stream = gen
	_sfx.bus = "SFX"
	_sfx.volume_db = sfx_volume_db
	add_child(_sfx)
	_sfx.play()
	_pb = _sfx.get_stream_playback()


func end_intro() -> void:
	intro = false
	# Baja la música suavemente al volumen de juego.
	create_tween().tween_property(_music, "volume_db", music_volume_game_db, 1.5)
	_puff = 1.0
	_start_boost = 1.0


func _exit_tree() -> void:
	_pb = null
	_music.stop()
	_sfx.stop()
	# El efecto vive en el AudioServer (global): quitarlo evita fugas al salir o recargar escena.
	var idx := AudioServer.get_bus_index("Music")
	for i in range(AudioServer.get_bus_effect_count(idx) - 1, -1, -1):
		if AudioServer.get_bus_effect(idx, i) == _music_lpf:
			AudioServer.remove_bus_effect(idx, i)


func _ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	return idx


func _process(delta: float) -> void:
	if car == null or _pb == null:
		return

	# --- Leer el estado de los thrusters ---
	var t := car.thrusters
	var vertical := 0.0
	for id in ["v_fl", "v_fr", "v_rl", "v_rr"]:
		vertical += (t[id] as Thruster).current
	var rcs := 0.0
	for id in ["rcs_f_px", "rcs_f_nx", "rcs_r_px", "rcs_r_nx"]:
		rcs += (t[id] as Thruster).current
	var rear := ((t["rear_l"] as Thruster).current + (t["rear_r"] as Thruster).current) * 0.5
	var boosting := Input.is_action_pressed("boost") and car.fuel > 0.0

	# "Puff" percusivo cuando un thruster lateral se enciende (gas frío = golpe seco).
	var rcs_on := rcs > 0.1
	if rcs_on and not _rcs_was_on:
		_puff = 1.0
	_rcs_was_on = rcs_on

	var hiss_target := clampf(vertical * 0.22 + rcs * 0.25, 0.0, 1.0)
	var rumble_target := clampf(rear * (1.4 if boosting else 1.0), 0.0, 1.4)
	var s := car.suction
	var fan_target := 0.0
	if s.active:
		fan_target = 0.35 + 0.4 * s.strength if s.connected else 0.2
	var fan_freq_target := 110.0 + 160.0 * s.strength

	_start_boost = maxf(_start_boost - delta * 1.2, 0.0)
	if intro:
		hiss_target = 0.22 + 0.06 * sin(Time.get_ticks_msec() * 0.004)
		rumble_target = 0.28
	else:
		hiss_target = clampf(hiss_target + _start_boost * 0.6, 0.0, 1.0)
		rumble_target += _start_boost * 1.0

	# --- Música: el filtro se abre con la velocidad (en la portada, sin filtro) ---
	var speed_ratio := 1.0 if intro else clampf(car.speed_kmh / 144.0, 0.0, 1.0)
	var target_cut := lerpf(900.0, 20000.0, speed_ratio * speed_ratio)
	_music_lpf.cutoff_hz = lerpf(_music_lpf.cutoff_hz, target_cut, 1.0 - exp(-3.0 * delta))

	# --- Rellenar el buffer del generador ---
	var frames := _pb.get_frames_available()
	if frames <= 0:
		return
	var inv := 1.0 / frames
	var h0 := _hiss_gain
	var r0 := _rumble_gain
	var f0 := _fan_gain
	var fq0 := _fan_freq
	var tone_target := 0.25 if boosting else 0.08  # boost = rugido más brillante
	var buf := PackedVector2Array()
	buf.resize(frames)
	for i in frames:
		var k := i * inv
		var hg := lerpf(h0, hiss_target, k)
		var rg := lerpf(r0, rumble_target, k)
		var fg := lerpf(f0, fan_target, k)
		var fq := lerpf(fq0, fan_freq_target, k)
		_rumble_tone = lerpf(_rumble_tone, tone_target, 0.0005)

		var white := randf() * 2.0 - 1.0
		# Siseo: paso-alto de 1 polo sobre ruido blanco.
		var hp := 0.92 * (_hp_prev_out + white - _hp_prev_in)
		_hp_prev_in = white
		_hp_prev_out = hp
		# Rugido: ruido marrón (integrado) + paso-bajo cuyo brillo sube con el boost.
		_brown = clampf(_brown * 0.995 + white * 0.04, -1.0, 1.0)
		_rumble_lp += (_brown - _rumble_lp) * (0.05 + _rumble_tone)
		# Ventilador: diente de sierra suave + armónico.
		_fan_phase = fmod(_fan_phase + fq / MIX_RATE, 1.0)
		var fan := sin(TAU * _fan_phase) * 0.6 + sin(TAU * _fan_phase * 3.0) * 0.15 + white * 0.08
		# Puff: ráfaga de ruido con caída exponencial.
		var puff := white * _puff
		_puff *= 0.9993

		var v := hp * hg * 0.55 + _rumble_lp * rg * 1.6 + fan * fg * 0.25 + puff * 0.35
		v = clampf(v, -1.0, 1.0)
		buf[i] = Vector2(v, v)
	_pb.push_buffer(buf)
	_hiss_gain = hiss_target
	_rumble_gain = rumble_target
	_fan_gain = fan_target
	_fan_freq = fan_freq_target
