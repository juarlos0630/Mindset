extends CharacterBody2D

const SPEED = 250.0
const JUMP_VELOCITY = -400.0

#Dash variables
const dash_speed = 900.0
const dash_duration = 0.15
const dash_cooldown = 0.5
var is_dashing = false
var can_dash = true
var dash_timer = 0.0 
var dash_cooldown_timer = 0.0
var dash_direction = 1.0

var time_passed = 0.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var is_attacking = false
var is_time_slowed = false

var slow_motion_timer = 0.0
const SLOW_MOTION_DURATION = 3.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var mapple = $Mapple

# Nueva variable para saber a qué lado debe volar Mapple
var target_mapple_x = -120.0 

func _ready():
	animated_sprite.animation_finished.connect(_on_animation_finished)

func _process(delta):
	time_passed += delta * 3.0
	
	# COMPORTAMIENTO DE MAPPLE (Flotación y seguimiento suave)
	if mapple.visible:
		# 1. Altura flotante
		var target_y = animated_sprite.position.y - 50 + (sin(time_passed) * 5.0)
		
		# 2. Lerp (Interpolación) para que el movimiento X e Y sea fluido y no se teletransporte
		mapple.position.x = lerp(mapple.position.x, target_mapple_x, 5.0 * delta)
		mapple.position.y = lerp(mapple.position.y, target_y, 5.0 * delta)

	# Temporizador de Bullet Time
	if is_time_slowed:
		slow_motion_timer -= delta / Engine.time_scale
		if slow_motion_timer <= 0:
			deactivate_bullet_time()

func _physics_process(delta):
	#Cooldown del dash
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer-=delta
		
	#Recargar el dash al tocar el suelo
	if is_on_floor():
		can_dash = true
	
	
	#Iniciar dash
	var can_start_dash = can_dash and dash_cooldown_timer <= 0.0 and not is_attacking and not is_dashing
	if Input.is_action_just_pressed("dash") and can_start_dash:
		start_dash()
	
	if is_dashing:
		dash_timer -= delta
		velocity.x = dash_direction * dash_speed
		velocity.y = 0.0
		if dash_timer <= 0.0:
			end_dash()
		move_and_slide()
		return
		
	# Gravedad
	if not is_on_floor():
		velocity.y += gravity * delta

	# Activar Bullet Time
	if Input.is_action_just_pressed("ui_focus_next"):
		if not is_time_slowed:
			activate_bullet_time()

	# Atacar
	if Input.is_action_just_pressed("ui_select") and not is_attacking:
		is_attacking = true
		animated_sprite.play("attack")

	# Saltar
	if Input.is_action_just_pressed("ui_up") and is_on_floor() and not is_attacking:
		velocity.y = JUMP_VELOCITY
		animated_sprite.play("jump") #Aquí va la reproducción de la animación

	# Movimiento y estado de animación
	# Movimiento y estado de animación
	if not is_attacking:
		var direction = Input.get_axis("ui_left", "ui_right")
		
		if direction != 0:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

		# Control de animaciones según si está en el suelo o saltando/cayendo
		if is_on_floor():
			if direction != 0:
				animated_sprite.play("walk")
			else:
				animated_sprite.play("idle")
		else:
			# Si está en el aire (saltando o cayendo)
			animated_sprite.play("jump")

		# Actualizar orientación de los sprites y decirle a Mapple hacia dónde volar
		if direction < 0:
			animated_sprite.flip_h = true
			mapple.flip_h = true
			target_mapple_x = animated_sprite.position.x + 120.0
		elif direction > 0:
			animated_sprite.flip_h = false
			mapple.flip_h = false
			target_mapple_x = animated_sprite.position.x - 120.0

	move_and_slide()

#Dash
func start_dash():
	var input_dir = Input.get_axis("ui_left", "ui_right")
	if input_dir != 0:
		dash_direction = sign(input_dir)
	else:
		dash_direction = -1.0 if animated_sprite.flip_h else 1.0
 
	is_dashing = true
	can_dash = false
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
 
	# Orientar sprites y Mapple hacia el dash
	animated_sprite.flip_h = dash_direction < 0
	mapple.flip_h = dash_direction < 0
	target_mapple_x = animated_sprite.position.x - (120.0 * dash_direction)
 
	# Solo reproduce "dash" si ya existe esa animación en el SpriteFrames
	if animated_sprite.sprite_frames.has_animation("dash"):
		animated_sprite.play("dash")
 
func end_dash():
	is_dashing = false
	velocity.x = dash_direction * SPEED  # entrega suave al movimiento normal

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
	

	
