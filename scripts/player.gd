extends CharacterBody2D

const SPEED = 250.0
var time_passed = 0.0

# Variables para el estado de ataque y la habilidad
var is_attacking = false
var is_time_slowed = false

# Duración del tiempo lento en segundos
var slow_motion_timer = 0.0
const SLOW_MOTION_DURATION = 3.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var mapple = $Mapple

func _ready():
	# Conecta la señal para saber cuándo termina la animación de golpe
	animated_sprite.animation_finished.connect(_on_animation_finished)

func _process(delta):
	# Efecto de flotación para Mapple
	time_passed += delta * 3.0
	mapple.position.y = -50 + sin(time_passed) * 5.0 # Sube y baja suavemente

	# Temporizador para la ralentización del tiempo
	if is_time_slowed:
		# Se usa el tiempo real (no afectado por la escala del tiempo)
		slow_motion_timer -= delta / Engine.time_scale
		if slow_motion_timer <= 0:
			deactivate_bullet_time()

func _physics_process(_delta):
	# 1. HABILIDAD: Ralentizar tiempo (tecla Shift / ui_focus_next)
	if Input.is_action_just_pressed("ui_focus_next"):
		if not is_time_slowed:
			activate_bullet_time()

	# 2. ATAQUE: Golpear (Barra Espaciadora / ui_select)
	if Input.is_action_just_pressed("ui_select") and not is_attacking:
		is_attacking = true
		animated_sprite.play("attack")

	# 3. MOVIMIENTO: Solo si no está atacando
	if not is_attacking:
		var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		
		if direction != Vector2.ZERO:
			velocity = direction * SPEED
			animated_sprite.play("walk")
		else:
			velocity = velocity.move_toward(Vector2.ZERO, SPEED)
			animated_sprite.play("idle")

		# Giro de personaje y de Mapple según la dirección
		if direction.x < 0:
			animated_sprite.flip_h = true
			mapple.flip_h = true
			mapple.position.x = 120
		elif direction.x > 0:
			animated_sprite.flip_h = false
			mapple.flip_h = false
			mapple.position.x = -120

	move_and_slide()

# Función que se ejecuta al terminar cualquier animación
func _on_animation_finished():
	if animated_sprite.animation == "attack":
		is_attacking = false

# Funciones de la habilidad "Bullet Time"
func activate_bullet_time():
	is_time_slowed = true
	slow_motion_timer = SLOW_MOTION_DURATION
	Engine.time_scale = 0.3 # Reduce el tiempo al 30%
	mapple.visible = false  # Oculta a Mapple

func deactivate_bullet_time():
	is_time_slowed = false
	Engine.time_scale = 1.0 # Restaura el tiempo normal
	mapple.visible = true   # Vuelve a mostrar a Mapple
