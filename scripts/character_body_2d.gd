extends CharacterBody2D

const SPEED = 250.0
const JUMP_VELOCITY = -400.0

var time_passed = 0.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var is_attacking = false
var is_time_slowed = false

var slow_motion_timer = 0.0
const SLOW_MOTION_DURATION = 3.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var mapple = $Mapple

func _ready():
	animated_sprite.animation_finished.connect(_on_animation_finished)

func _process(delta):
	time_passed += delta * 3.0
	
	# Mapple mantiene su altura flotando cerca de Oliver
	mapple.position.y = animated_sprite.position.y - 50 + (sin(time_passed) * 5.0)

	# CORRECCIÓN: Temporizador de Bullet Time restaurado para que dure solo 3 segundos
	if is_time_slowed:
		slow_motion_timer -= delta / Engine.time_scale
		if slow_motion_timer <= 0:
			deactivate_bullet_time()

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("ui_focus_next"):
		if not is_time_slowed:
			activate_bullet_time()

	if Input.is_action_just_pressed("ui_select") and not is_attacking:
		is_attacking = true
		animated_sprite.play("attack")

	if Input.is_action_just_pressed("ui_up") and is_on_floor() and not is_attacking:
		velocity.y = JUMP_VELOCITY

	if not is_attacking:
		var direction = Input.get_axis("ui_left", "ui_right")
		
		if direction != 0:
			velocity.x = direction * SPEED
			if is_on_floor():
				animated_sprite.play("walk")
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			if is_on_floor():
				animated_sprite.play("idle")

		# CORRECCIÓN: Se aumentó la distancia a 60 para separar más a Mapple
		if direction < 0:
			animated_sprite.flip_h = true
			mapple.flip_h = true
			mapple.position.x = animated_sprite.position.x + 120
		elif direction > 0:
			animated_sprite.flip_h = false
			mapple.flip_h = false
			mapple.position.x = animated_sprite.position.x - 120

	move_and_slide()

func _on_animation_finished():
	if animated_sprite.animation == "attack":
		is_attacking = false

func activate_bullet_time():
	is_time_slowed = true
	slow_motion_timer = SLOW_MOTION_DURATION
	Engine.time_scale = 0.3 
	mapple.visible = false  

func deactivate_bullet_time():
	is_time_slowed = false
	Engine.time_scale = 1.0 
	mapple.visible = true
