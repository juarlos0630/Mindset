extends CharacterBody2D

enum Estado { IDLE, LANZAR, RECORRER, EXTRA }
enum Fase { PREPARAR, DISPARAR, RECUPERAR }

@export var moneda_scene: PackedScene
@export var mira_a_la_derecha_por_defecto = true 
@export_group("Escenario (X global)")
@export var limite_izquierdo = 100.0
@export var limite_derecho = 1000.0

@export_group("Pausa entre patrones")
@export var pausa_min = 0.8
@export var pausa_max = 1.4

@export_group("Patrón: lanzar monedas")
@export var monedas_por_rafaga = 4
@export var tiempo_preparacion = 0.5      # aviso antes de lanzar
@export var intervalo_monedas = 0.35
@export var tiempo_vuelo_moneda = 0.9     # más alto = moneda más lenta y fácil de esquivar
@export var tiempo_recuperacion = 0.6

@export_group("Patrón: recorrer escenario")
@export var velocidad_recorrido = 180.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var estado = Estado.IDLE
var ultimo_patron = Estado.IDLE
var fase = Fase.PREPARAR
var timer = 0.0
var monedas_restantes = 0
var objetivo_x = 0.0
var punto_x_base = 0.0
var player: Node2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var punto_lanzamiento = $PuntoLanzamiento
@onready var hitbox = get_node_or_null("Hitbox")  # opcional: daño por contacto al recorrer

func _ready():
	add_to_group("jefe")
	player = get_tree().get_first_node_in_group("player")
	# Guarda la posición del punto de lanzamiento "mirando a la derecha"
	punto_x_base = punto_lanzamiento.position.x * (1.0 if mira_a_la_derecha_por_defecto else -1.0)
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	_cambiar_estado(Estado.IDLE)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	match estado:
		Estado.IDLE:
			_proceso_idle(delta)
		Estado.LANZAR:
			_proceso_lanzar(delta)
		Estado.RECORRER:
			_proceso_recorrer(delta)
		Estado.EXTRA:
			_proceso_extra(delta)

	move_and_slide()

#CAMBIO DE ESTADO 
func _cambiar_estado(nuevo):
	estado = nuevo
	match nuevo:
		Estado.IDLE:
			timer = randf_range(pausa_min, pausa_max)
			velocity.x = 0.0
			_reproducir("idle")
		Estado.LANZAR:
			fase = Fase.PREPARAR
			timer = tiempo_preparacion
			monedas_restantes = monedas_por_rafaga
			velocity.x = 0.0
			_mirar_al_jugador()
			_reproducir("lanzar")
			animated_sprite.modulate = Color(1.0, 0.7, 0.7)  # aviso visual
		Estado.RECORRER:
			# va al borde más lejano de donde está
			if abs(global_position.x - limite_izquierdo) < abs(global_position.x - limite_derecho):
				objetivo_x = limite_derecho
			else:
				objetivo_x = limite_izquierdo
			_reproducir("walk")
		Estado.EXTRA:
			_iniciar_extra()

func _elegir_siguiente_patron():
	var opciones = [Estado.LANZAR, Estado.RECORRER]  # <- agrega aquí los patrones nuevos
	if opciones.size() > 1:
		opciones.erase(ultimo_patron)  # no repite el mismo patrón dos veces seguidas
	var elegido = opciones.pick_random()
	ultimo_patron = elegido
	_cambiar_estado(elegido)

#ESTADO: IDLE 
func _proceso_idle(delta):
	_mirar_al_jugador()
	timer -= delta
	if timer <= 0.0:
		_elegir_siguiente_patron()

#PATRÓN 1: LANZAR MONEDAS (quieto)
func _proceso_lanzar(delta):
	timer -= delta
	if timer > 0.0:
		return

	match fase:
		Fase.PREPARAR:
			animated_sprite.modulate = Color.WHITE
			fase = Fase.DISPARAR
			_lanzar_moneda()
			monedas_restantes -= 1
			timer = intervalo_monedas
		Fase.DISPARAR:
			if monedas_restantes > 0:
				_mirar_al_jugador()
				_lanzar_moneda()
				monedas_restantes -= 1
				timer = intervalo_monedas
			else:
				fase = Fase.RECUPERAR
				timer = tiempo_recuperacion
		Fase.RECUPERAR:
			_cambiar_estado(Estado.IDLE)

func _lanzar_moneda():
	if moneda_scene == null or player == null:
		return
	var moneda = moneda_scene.instantiate()
	get_parent().add_child(moneda)
	moneda.global_position = punto_lanzamiento.global_position

	# Tiro parabólico: la moneda cae donde estaba Oliver al momento del lanzamiento
	var t = tiempo_vuelo_moneda
	var d = player.global_position - moneda.global_position
	moneda.velocidad = Vector2(d.x / t, (d.y - 0.5 * gravity * t * t) / t)

#PATRÓN 2: RECORRER EL ESCENARIO
func _proceso_recorrer(delta):
	var dx = objetivo_x - global_position.x
	if abs(dx) <= max(8.0, velocidad_recorrido * delta) or is_on_wall():
		_cambiar_estado(Estado.IDLE)
		return
	var dir = sign(dx)
	velocity.x = dir * velocidad_recorrido
	_orientar(dir)

#PATRÓN 3: PENDIENTE
func _iniciar_extra():
	pass  # aquí va la preparación del patrón nuevo

func _proceso_extra(_delta):
	_cambiar_estado(Estado.IDLE)  # mientras no exista, regresa a IDLE

#UTILIDADES
func _mirar_al_jugador():
	if player:
		_orientar(sign(player.global_position.x - global_position.x))

func _orientar(dir):
	if dir == 0:
		return
	var mira_derecha = dir > 0
	animated_sprite.flip_h = (mira_derecha != mira_a_la_derecha_por_defecto)
	punto_lanzamiento.position.x = punto_x_base * (1.0 if mira_derecha else -1.0)

# Solo reproduce la animación si existe 
func _reproducir(nombre):
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(nombre):
		animated_sprite.play(nombre)

func _on_hitbox_body_entered(body):
	if estado == Estado.RECORRER and body.is_in_group("player"):
		if body.has_method("recibir_dano"):
			body.recibir_dano(1)
		else:
			print("El jefe golpeó a ", body.name)
