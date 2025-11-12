extends CharacterBody2D

@export var speed: float = 100
@export var attack_cooldown: float = 1.5
@export var patrol_points: Array[Vector2] = []  # ← puntos A, B, C, etc.
@export var wait_time: float = 1.0  # pausa entre puntos

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var vision_area: Area2D = $Area2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_timer: Timer = $AttackTimer
@onready var scream_player: AudioStreamPlayer2D = $ScreamPlayer

var player: Node2D = null
var can_attack: bool = true
var has_screamed: bool = false
var current_point_index: int = 0
var waiting: bool = false
var wait_timer: float = 0.0
var spawn_position: Vector2
var state: String = "patrolling" # estados: patrolling / chasing / returning

func _ready() -> void:
	spawn_position = global_position
	$CollisionShape2D.disabled = false

	vision_area.body_entered.connect(_on_body_entered)
	vision_area.body_exited.connect(_on_body_exited)
	attack_area.body_entered.connect(_on_attack_area_entered)
	attack_timer.timeout.connect(_on_attack_timeout)

	sprite.play("idle")

func _physics_process(delta: float) -> void:
	match state:
		"patrolling":
			_patrol(delta)
		"chasing":
			_chase_player(delta)
		"returning":
			_return_to_spawn(delta)

# --- Patrullaje ---
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

# --- Persecución ---
func _chase_player(delta: float) -> void:
	if not player:
		state = "returning"
		return

	var dir = (player.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	sprite.play("default")
	sprite.flip_h = velocity.x < 0

# --- Regresar a punto inicial ---
func _return_to_spawn(delta: float) -> void:
	var dir = (spawn_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	sprite.play("default")
	sprite.flip_h = velocity.x < 0

	if global_position.distance_to(spawn_position) < 8.0:
		state = "patrolling"

# --- Señales ---
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

func _on_attack_area_entered(body: Node2D) -> void:
	if body.name == "Player" and can_attack:
		can_attack = false
		sprite.play("attack")
		attack_timer.start(attack_cooldown)
		await get_tree().create_timer(0.5).timeout
		get_tree().reload_current_scene()

func _on_attack_timeout() -> void:
	can_attack = true
