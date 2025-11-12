extends Node2D

@onready var luz: PointLight2D = $Luz
@onready var sonido_on: AudioStreamPlayer2D = $SonidoOn
@onready var sonido_off: AudioStreamPlayer2D = $SonidoOff

var encendida := false
var f_down := false

func _ready() -> void:
	luz.enabled = false

func _process(_delta: float) -> void:
	if Input.is_key_pressed(KEY_F):
		if not f_down:
			f_down = true
			encendida = !encendida
			luz.enabled = encendida

			# Reproducir sonidos según estado
			if encendida:
				if sonido_on:
					sonido_on.play()
			else:
				if sonido_off:
					sonido_off.play()

			# Mostrar estado en consola
			print("Linterna encendida:", encendida)
	else:
		f_down = false
