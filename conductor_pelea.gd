extends CharacterBody2D

@export var vida_maxima: int = 120   # 120 = 8 golpes de Oliver (15 c/u) para coincidir con los 4 tramos de 2 golpes
@export var velocidad: float = 280.0
@export var fuerza_salto: float = -540.0
@export var gravedad: float = 980.0

# Hacia dónde miran los dibujos ORIGINALES (sin voltear)
@export var sprite_mira_a_la_derecha: bool = true
@export var ataque_mira_a_la_derecha: bool = true  # cámbiala si el golpe sale al revés
@export var salto_mira_a_la_derecha: bool = false 
@export var idle_mira_a_la_derecha: bool = false


# Ataque del conductor
@export var distancia_parar: float = 45.0
@export var alcance_golpe: float = 80.0
@export var altura_golpe: float = 80.0
@export var dano_al_jugador: int = 12
@export var cooldown_golpe: float = 1.2
@export var tiempo_impacto: float = 0.25   # segundo de la animación en que pega

# Cuando Oliver le pega al conductor (más chico = tienes que estar más cerca)
@export var alcance_recibir_x: float = 60.0
@export var alcance_recibir_y: float = 60.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var mi_colision: CollisionShape2D = $CollisionShape2D
@onready var barra_conductor: AnimatedSprite2D = $"../CanvasLayer/BarraConductor"
@onready var you_win_screen: TextureRect = $"../CanvasLayer/YouWinScreen"

var vida_actual: int
var golpes_recibidos: int = 0
var jefe_derrotado: bool = false
var oliver: Node2D = null
var oliver_colision: Node2D = null
var anim_oliver: AnimatedSprite2D = null

var mirando: float = 1.0
var atacando := false
var recibiendo_dano := false
var golpe_oliver_registrado := false
var cooldown_ataque := 0.0
var cooldown_salto := 0.0
var cooldown_recibir := 0.0


func _ready() -> void:
	vida_actual = vida_maxima
	if barra_conductor:
		barra_conductor.frame = 0
	if you_win_screen:
		you_win_screen.modulate.a = 0.0
		you_win_screen.visible = false
	collision_layer = 2
	collision_mask = 1
	# Para que la animación de golpe termine y no se repita en bucle
	if anim.sprite_frames.has_animation("ataque"):
		anim.sprite_frames.set_animation_loop("ataque", false)
	_buscar_oliver()


func _buscar_oliver() -> void:
	oliver = get_tree().get_first_node_in_group("player") as Node2D
	if oliver:
		oliver_colision = oliver.get_node_or_null("CollisionShape2D") as Node2D
		anim_oliver = oliver.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if oliver is CharacterBody2D:
			add_collision_exception_with(oliver)
			oliver.add_collision_exception_with(self)


func _centro_yo() -> Vector2:
	return mi_colision.global_position


func _centro_oliver() -> Vector2:
	if oliver_colision:
		return oliver_colision.global_position
	return oliver.global_position


func _aplicar_flip(dir: float, mira_derecha: bool) -> void:
	if dir == 0.0:
		return
	anim.flip_h = (dir < 0.0) if mira_derecha else (dir > 0.0)


func _voltear(dir: float) -> void:
	if dir == 0.0:
		return
	mirando = dir
	_aplicar_flip(dir, sprite_mira_a_la_derecha)


func _reproducir(nombre: String) -> void:
	if not anim.sprite_frames.has_animation(nombre):
		return
	if anim.animation != nombre:
		anim.play(nombre)
	# Cada animación puede estar dibujada mirando a un lado distinto
	if nombre == "salto":
		_aplicar_flip(mirando, salto_mira_a_la_derecha)
	else:
		_aplicar_flip(mirando, sprite_mira_a_la_derecha)


func _physics_process(delta: float) -> void:
	if jefe_derrotado:
		return

	if not is_on_floor():
		velocity.y += gravedad * delta

	if oliver == null:
		_buscar_oliver()
		move_and_slide()
		return

	cooldown_ataque = maxf(0.0, cooldown_ataque - delta)
	cooldown_salto = maxf(0.0, cooldown_salto - delta)
	cooldown_recibir = maxf(0.0, cooldown_recibir - delta)

	_revisar_golpe_de_oliver()

	if atacando or recibiendo_dano:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
		move_and_slide()
		return

	var diff: Vector2 = _centro_oliver() - _centro_yo()
	var dir: float = signf(diff.x)
	_voltear(dir)

	if is_on_floor() and cooldown_salto <= 0.0:
		if (diff.y < -110.0 and absf(diff.x) < 300.0) or is_on_wall():
			velocity.y = fuerza_salto
			cooldown_salto = 0.8

	if is_on_floor() and absf(diff.x) <= alcance_golpe and absf(diff.y) <= altura_golpe and cooldown_ataque <= 0.0:
		_atacar()
	elif absf(diff.x) > distancia_parar:
		velocity.x = dir * velocidad
		if is_on_floor():
			_reproducir("correr")
	else:
		velocity.x = 0.0
		if is_on_floor():
			_reproducir("idle")

	if not is_on_floor():
		_reproducir("salto")

	move_and_slide()


func _atacar() -> void:
	atacando = true
	cooldown_ataque = cooldown_golpe
	velocity.x = 0.0

	# Voltear hacia Oliver con la orientación propia del ataque
	var dir_inicial: float = signf(_centro_oliver().x - _centro_yo().x)
	if dir_inicial != 0.0:
		mirando = dir_inicial
	_aplicar_flip(mirando, ataque_mira_a_la_derecha)
	anim.play("ataque")

	# Momento del impacto
	await get_tree().create_timer(tiempo_impacto).timeout
	if not is_instance_valid(oliver) or recibiendo_dano or not atacando or jefe_derrotado:
		atacando = false
		return

	var diff: Vector2 = _centro_oliver() - _centro_yo()
	var al_frente: bool = signf(diff.x) == mirando or diff.x == 0.0
	if al_frente and absf(diff.x) <= alcance_golpe + 15.0 and absf(diff.y) <= altura_golpe:
		if oliver.has_method("recibir_dano"):
			oliver.recibir_dano(dano_al_jugador)

	# Esperar a que la animación de golpe termine completa
	var espera := 0.0
	while atacando and anim.is_playing() and anim.animation == "ataque" and espera < 2.0:
		await get_tree().process_frame
		espera += get_process_delta_time()

	atacando = false


func _oliver_me_mira() -> bool:
	if anim_oliver == null:
		return true
	# El sprite de Oliver mira a la derecha por defecto (flip_h = true → izquierda)
	var yo_a_la_derecha: bool = _centro_yo().x > _centro_oliver().x
	var oliver_mira_derecha: bool = not anim_oliver.flip_h
	return yo_a_la_derecha == oliver_mira_derecha


func _revisar_golpe_de_oliver() -> void:
	# Reiniciar el registro cuando Oliver termina su golpe
	if anim_oliver == null or anim_oliver.animation != "attack":
		golpe_oliver_registrado = false
		return
	if golpe_oliver_registrado or cooldown_recibir > 0.0 or recibiendo_dano or jefe_derrotado:
		return

	var diff: Vector2 = _centro_yo() - _centro_oliver()
	if absf(diff.x) <= alcance_recibir_x and absf(diff.y) <= alcance_recibir_y and _oliver_me_mira():
		golpe_oliver_registrado = true   # un golpe de Oliver = un solo daño
		_recibir_dano(15, signf(diff.x))


func _recibir_dano(cantidad: int, dir_empuje: float) -> void:
	if jefe_derrotado:
		return
	cooldown_recibir = 0.6
	recibiendo_dano = true
	atacando = false
	vida_actual -= cantidad
	golpes_recibidos += 1
	actualizar_barra_conductor()

	_reproducir("dano_jefe")

	velocity.x = (dir_empuje if dir_empuje != 0.0 else 1.0) * 200.0

	await get_tree().create_timer(0.45).timeout
	recibiendo_dano = false

	if vida_actual <= 0:
		mostrar_victoria()


func actualizar_barra_conductor() -> void:
	if not barra_conductor:
		return
	# División entera entre 2: cada 2 golpes avanza al siguiente frame (0, 1, 2, 3, 4)
	var nuevo_frame: int = golpes_recibidos / 2
	barra_conductor.frame = clamp(nuevo_frame, 0, 4)


func mostrar_victoria() -> void:
	if jefe_derrotado:
		return
	jefe_derrotado = true
	
	# Ocultamos al Conductor y desactivamos su colisión al instante
	anim.visible = false
	mi_colision.set_deferred("disabled", true)
	
	# Restauramos la velocidad normal del juego por si se derrotó en Bullet Time
	Engine.time_scale = 1.0
	
	if you_win_screen:
		you_win_screen.visible = true
		var tween := create_tween()
		tween.tween_property(you_win_screen, "modulate:a", 1.0, 1.5)
		await tween.finished
	
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/Nivel3/escenafinal.tscn")
