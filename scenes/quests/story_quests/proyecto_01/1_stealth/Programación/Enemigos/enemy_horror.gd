extends CharacterBody2D

# --- Variables principales ---
@export var speed: float = 100
@export var attack_cooldown: float = 1.5
@export var patrol_points: Array[Vector2] = []  # puntos A, B, C...
@export var wait_time: float = 1.0  # pausa entre puntos
@export var light_detection_area: Area2D  # área para detectar la linterna
@export var linterna: Node2D  # referencia directa a la linterna

# --- Referencias de nodos ---
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var vision_area: Area2D = $Area2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_timer: Timer = $AttackTimer
@onready var scream_player: AudioStreamPlayer2D = $ScreamPlayer

# --- Estados y variables internas ---
var player: Node2D = null
var can_attack: bool = true
var has_screamed: bool = false
var current_point_index: int = 0
var waiting: bool = false
var wait_timer: float = 0.0
var spawn_position: Vector2
var state: String = "patrolling" # patrolling / chasing / returning
var is_in_light: bool = false
var light_timer: float = 0.0

# --- Variables para repulsión ---
var repel_timer: float = 0.0
var is_repelled: bool = false
var repel_force: float = 250.0  # intensidad del retroceso


# --- READY ---
func _ready() -> void:
	spawn_position = global_position
	$CollisionShape2D.disabled = false

	# Conexiones normales
	vision_area.body_entered.connect(_on_body_entered)
	vision_area.body_exited.connect(_on_body_exited)
	attack_area.body_entered.connect(_on_attack_area_entered)
	attack_timer.timeout.connect(_on_attack_timeout)

	# Conexión para detección de luz (usando área_entered)
	if light_detection_area:
		light_detection_area.area_entered.connect(_on_light_entered)
		light_detection_area.area_exited.connect(_on_light_exited)

	sprite.play("idle")


# --- PROCESO PRINCIPAL ---
func _physics_process(delta: float) -> void:
	# Si está siendo repelido, no ejecutar la lógica normal
	if is_repelled:
		move_and_slide()
		return

	match state:
		"patrolling":
			_patrol(delta)
		"chasing":
			_chase_player(delta)
		"returning":
			_return_to_spawn(delta)

	# Verificar si debe ser repelido por la linterna
	_check_repel(delta)


# --- PATRULLAJE ---
func _patrol(delta: float) -> void:
	if patrol_points.is_empty():
		sprite.play("idle")
		return

	if waiting:
		wait_timer -= delta
		if wait_timer <= 0:
			waiting = false
		return

	var target = patrol_points[current_point_index]
	var direction = (target - global_position).normalized()
	velocity = direction * speed
	move_and_slide()
	sprite.play("default")
	sprite.flip_h = velocity.x < 0

	# Si llega al punto
	if global_position.distance_to(target) < 8.0:
		waiting = true
		wait_timer = wait_time
		current_point_index = (current_point_index + 1) % patrol_points.size()
		sprite.play("idle")


# --- PERSECUCIÓN ---
func _chase_player(delta: float) -> void:
	if not player:
		state = "returning"
		return

	var dir = (player.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	sprite.play("default")
	sprite.flip_h = velocity.x < 0


# --- REGRESAR AL PUNTO INICIAL ---
func _return_to_spawn(delta: float) -> void:
	var dir = (spawn_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	sprite.play("default")
	sprite.flip_h = velocity.x < 0

	if global_position.distance_to(spawn_position) < 8.0:
		state = "patrolling"


# --- DETECCIÓN DEL JUGADOR ---
func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player = body
		state = "chasing"

		if not has_screamed:
			has_screamed = true
			if scream_player.playing:
				scream_player.stop()
			scream_player.play()


func _on_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		has_screamed = false
		state = "returning"


# --- ATAQUE ---
func _on_attack_area_entered(body: Node2D) -> void:
	if body.name == "Player" and can_attack:
		can_attack = false
		sprite.play("attack")
		attack_timer.start(attack_cooldown)
		await get_tree().create_timer(0.5).timeout
		get_tree().reload_current_scene()


func _on_attack_timeout() -> void:
	can_attack = true


# --- DETECCIÓN DE LUZ ---
func _on_light_entered(area: Area2D) -> void:
	if area.name == "LightArea":
		is_in_light = true
		print("💡 El monstruo ha entrado en el área de la linterna")


func _on_light_exited(area: Area2D) -> void:
	if area.name == "LightArea":
		is_in_light = false
		light_timer = 0.0
		repel_timer = 0.0
		print("🌑 El monstruo salió del área de la linterna")


# --- REPULSIÓN POR LUZ ---
func _check_repel(delta: float) -> void:
	if not linterna:
		return

	# si la linterna está encendida y el enemigo está dentro del área
	if is_in_light and linterna.encendida:
		repel_timer += delta
		if repel_timer >= 3.0 and not is_repelled:
			_apply_repel()
	else:
		repel_timer = 0.0


func _apply_repel() -> void:
	is_repelled = true
	print("🔥 El monstruo fue repelido por la linterna")

	# Dirección opuesta a la luz
	var dir = (global_position - linterna.global_position).normalized()
	velocity = dir * repel_force
	move_and_slide()

	await get_tree().create_timer(0.5).timeout
	is_repelled = false
