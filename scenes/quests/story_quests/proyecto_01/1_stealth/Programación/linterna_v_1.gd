extends Node2D

@onready var luz: PointLight2D = $Luz
@onready var sonido_on: AudioStreamPlayer2D = $SonidoOn
@onready var sonido_off: AudioStreamPlayer2D = $SonidoOff
@onready var duration_timer: Timer = $DurationTimer
@onready var cooldown_timer: Timer = $CooldownTimer

var encendida := false
var f_down := false
var usable := true

var max_duration := 10.0  # Duración máxima encendida
var cooldown_time := 5.0  # Tiempo de espera antes de volver a usar

func _ready() -> void:
	luz.enabled = false
	duration_timer.one_shot = true
	cooldown_timer.one_shot = true
	duration_timer.timeout.connect(_on_duration_timeout)
	cooldown_timer.timeout.connect(_on_cooldown_timeout)

func _process(_delta: float) -> void:
	if Input.is_key_pressed(KEY_F):
		if not f_down and usable:
			f_down = true
			_toggle_light()
	else:
		f_down = false

func _toggle_light() -> void:
	encendida = !encendida
	luz.enabled = encendida

	if encendida:
		if sonido_on: sonido_on.play()
		duration_timer.start(max_duration)
	else:
		if sonido_off: sonido_off.play()
		duration_timer.stop()

func _on_duration_timeout() -> void:
	# Cuando se acaba el tiempo, se apaga
	encendida = false
	luz.enabled = false
	if sonido_off: sonido_off.play()
	print("🔋 La linterna se agotó. Esperando recarga...")
	usable = false
	cooldown_timer.start(cooldown_time)

func _on_cooldown_timeout() -> void:
	print("✅ Linterna recargada.")
	usable = true
