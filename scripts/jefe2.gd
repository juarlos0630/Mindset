extends CharacterBody2D

# Jefe 2: la caja de cereales. Estados: pausa, caminar, disparar, recibir daño y muerto.
#
# Animaciones que espera el AnimatedSprite2D (ya vienen en jefe_2_frames.tres):
#   idle, caminar, disparo, dano
#
# Para agregar un patrón nuevo: suma un valor a Estado, implementa su _proceso_xxx
# y agrégalo a la lista "opciones" de _elegir_siguiente_patron().

signal vida_cambiada(actual, maxima)
signal derrotado

enum Estado { IDLE, CAMINAR, DISPARAR, DANO, MUERTO }

@export var cereal_scene: PackedScene
@export var mira_a_la_derecha_por_defecto = true   # ¿el sprite original mira a la derecha?

@export_group("Vida")
@export var vida_maxima = 10
@export var tiempo_invulnerable = 0.5      # segundos sin poder recibir otro golpe
@export var empuje_al_recibir_dano = 90.0
@export var el_dano_interrumpe_el_disparo = true
@export_file("*.tscn") var escena_al_derrotar = ""   # vacío = solo desaparece y emite "derrotado"

@export_group("Escenario (X global)")
@export var limite_izquierdo = 100.0
@export var limite_derecho = 1000.0

@export_group("Caminar")
@export var velocidad_caminar = 130.0
@export var rango_disparo = 450.0          # a esta distancia o menos ya puede disparar
@export var tiempo_max_caminar = 2.5

@export_group("Disparo")
@export var disparos_por_rafaga = 2
@export var frame_disparo = 2              # frame de "disparo" en el que sale el cereal
@export var prob_cereal_pequeno = 0.4      # 0 = solo grandes, 1 = solo pequeños
@export var velocidad_cereal_grande = 320.0
@export var velocidad_cereal_pequeno = 460.0
@export var dispersion_grados = 5.0
@export var escala_cereal_grande = 0.28    # relativa a la escala del sprite del jefe
@export var escala_cereal_pequeno = 1.6

@export_group("Pausa entre acciones")
@export var pausa_min = 0.6
@export var pausa_max = 1.2

@export_group("Pruebas")
@export var tecla_prueba_dano = true       # J = quitarle 1 de vida (solo en ejecuciones desde el editor)

# Punta de la mano con el brazo extendido, respecto al centro del sprite
# (en píxeles del frame original, mirando a la derecha).
const MANO_DISPARO = Vector2(140, -8)

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var estado = Estado.IDLE
var ultimo_patron = Estado.IDLE
var vida = 0
var timer = 0.0                 # temporizador del estado actual
var invulnerable_timer = 0.0
var objetivo_x = 0.0
var rafaga_restante = 0
var player: Node2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox = get_node_or_null("Hitbox")   # opcional: daño por contacto al caminar

func _ready():
	add_to_group("jefe")
	vida = vida_maxima
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.frame_changed.connect(_on_frame_changed)
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	vida_cambiada.emit(vida, vida_maxima)
	_cambiar_estado(Estado.IDLE)

func _unhandled_input(event):
	if tecla_prueba_dano and OS.is_debug_build() \
			and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_J:
		recibir_dano(1)

func _physics_process(delta):
	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
	if not is_on_floor():
		velocity.y += gravity * delta

	match estado:
		Estado.IDLE:
			_proceso_idle(delta)
		Estado.CAMINAR:
			_proceso_caminar(delta)
		Estado.DISPARAR:
			_proceso_disparar(delta)
		Estado.DANO:
			_proceso_dano(delta)
		Estado.MUERTO:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)

	move_and_slide()

# ---------------------------------------------------------------- estados
func _cambiar_estado(nuevo):
	estado = nuevo
	match nuevo:
		Estado.IDLE:
			timer = randf_range(pausa_min, pausa_max)
			velocity.x = 0.0
			_reproducir("idle")
		Estado.CAMINAR:
			timer = tiempo_max_caminar
			_elegir_destino()
			_reproducir("caminar")
		Estado.DISPARAR:
			timer = 1.5 * disparos_por_rafaga + 1.0   # tope de seguridad por si falta la animación
			velocity.x = 0.0
			rafaga_restante = disparos_por_rafaga
			_mirar_al_jugador()
			_reproducir("disparo")
		Estado.DANO:
			timer = 1.2                    # tope de seguridad
			_reproducir("dano")

func _elegir_siguiente_patron():
	var j = _jugador()
	# lejos del jugador: se acerca
	if j and abs(j.global_position.x - global_position.x) > rango_disparo:
		ultimo_patron = Estado.CAMINAR
		_cambiar_estado(Estado.CAMINAR)
		return
	# a distancia de tiro: dispara casi siempre, a veces se reposiciona
	var opciones = [Estado.DISPARAR, Estado.DISPARAR, Estado.CAMINAR]
	if ultimo_patron == Estado.CAMINAR:
		opciones = [Estado.DISPARAR]        # después de moverse, dispara
	var elegido = opciones.pick_random()
	ultimo_patron = elegido
	_cambiar_estado(elegido)

# --- IDLE
func _proceso_idle(delta):
	_mirar_al_jugador()
	timer -= delta
	if timer <= 0.0:
		_elegir_siguiente_patron()

# --- CAMINAR
func _elegir_destino():
	var j = _jugador()
	if j and abs(j.global_position.x - global_position.x) > rango_disparo:
		# acercarse hasta quedar al 80 % del rango de tiro
		var lado = sign(global_position.x - j.global_position.x)
		if lado == 0.0:
			lado = 1.0
		objetivo_x = j.global_position.x + lado * rango_disparo * 0.8
	else:
		# reposicionarse: ir hacia el extremo más lejano del escenario
		if abs(global_position.x - limite_izquierdo) < abs(global_position.x - limite_derecho):
			objetivo_x = limite_derecho
		else:
			objetivo_x = limite_izquierdo
	objetivo_x = clamp(objetivo_x, limite_izquierdo, limite_derecho)

func _proceso_caminar(delta):
	timer -= delta
	var dx = objetivo_x - global_position.x
	if abs(dx) <= max(8.0, velocidad_caminar * delta) or timer <= 0.0 or is_on_wall():
		_cambiar_estado(Estado.IDLE)
		return
	var dir = sign(dx)
	velocity.x = dir * velocidad_caminar
	_orientar(dir)

# --- DISPARAR
func _proceso_disparar(delta):
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	timer -= delta
	if timer <= 0.0:
		_cambiar_estado(Estado.IDLE)

func _on_frame_changed():
	# el cereal sale justo en el frame en que el brazo está extendido
	if estado == Estado.DISPARAR and animated_sprite.animation == "disparo" \
			and animated_sprite.frame == frame_disparo:
		_lanzar_cereal()

func _lanzar_cereal():
	if cereal_scene == null:
		push_warning("Falta asignar Cereal Scene en el Inspector del jefe.")
		return
	var lado = 1.0 if _mira_derecha() else -1.0
	var origen = animated_sprite.to_global(Vector2(MANO_DISPARO.x * lado, MANO_DISPARO.y))

	var objetivo = origen + Vector2(lado * 400.0, 0.0)   # sin jugador: tiro recto
	var j = _jugador()
	if j:
		objetivo = j.global_position
	var dir = (objetivo - origen).normalized()
	dir = dir.rotated(deg_to_rad(randf_range(-dispersion_grados, dispersion_grados)))

	var grande = randf() >= prob_cereal_pequeno
	var cereal = cereal_scene.instantiate()
	cereal.grande = grande
	cereal.escala = abs(animated_sprite.global_scale.x) \
			* (escala_cereal_grande if grande else escala_cereal_pequeno)
	cereal.velocidad = dir * (velocidad_cereal_grande if grande else velocidad_cereal_pequeno)
	get_parent().add_child(cereal)
	cereal.global_position = origen

# --- DAÑO
func recibir_dano(cantidad = 1, desde_x = null):
	if estado == Estado.MUERTO or invulnerable_timer > 0.0:
		return
	vida = max(vida - cantidad, 0)
	vida_cambiada.emit(vida, vida_maxima)
	if vida <= 0:
		_morir()
		return
	invulnerable_timer = tiempo_invulnerable

	if estado == Estado.DISPARAR and not el_dano_interrumpe_el_disparo:
		_destello()                          # sigue disparando, solo parpadea
		return

	_cambiar_estado(Estado.DANO)
	var lado = -1.0 if _mira_derecha() else 1.0      # por defecto lo empuja hacia atrás
	if desde_x != null and desde_x != global_position.x:
		lado = sign(global_position.x - desde_x)     # lejos de quien lo golpeó
	velocity.x = lado * empuje_al_recibir_dano

func _proceso_dano(delta):
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	timer -= delta
	if timer <= 0.0:
		_cambiar_estado(Estado.IDLE)

func _destello():
	var t = create_tween()
	animated_sprite.modulate = Color(1.0, 0.6, 0.6)
	t.tween_property(animated_sprite, "modulate", Color.WHITE, 0.25)

func _morir():
	estado = Estado.MUERTO
	collision_layer = 0                      # ya no lo tocan Oliver ni los proyectiles
	if hitbox:
		hitbox.set_deferred("monitoring", false)
	_reproducir("dano")
	derrotado.emit()

	var t = create_tween()
	t.tween_interval(0.8)
	t.tween_property(self, "modulate:a", 0.0, 1.0)
	await t.finished
	if escena_al_derrotar != "" and ResourceLoader.exists(escena_al_derrotar):
		get_tree().change_scene_to_file(escena_al_derrotar)
	else:
		queue_free()

# ---------------------------------------------------------------- animaciones
func _on_animation_finished():
	match animated_sprite.animation:
		"disparo":
			if estado != Estado.DISPARAR:
				return
			rafaga_restante -= 1
			if rafaga_restante > 0:
				_mirar_al_jugador()
				animated_sprite.play("disparo")      # siguiente disparo de la ráfaga
			else:
				_cambiar_estado(Estado.IDLE)
		"dano":
			if estado == Estado.DANO:
				_cambiar_estado(Estado.IDLE)

# Solo reproduce la animación si existe y tiene fotogramas (no truena si falta alguna)
func _reproducir(nombre):
	var frames = animated_sprite.sprite_frames
	if frames and frames.has_animation(nombre) and frames.get_frame_count(nombre) > 0:
		animated_sprite.play(nombre)

# ---------------------------------------------------------------- utilidades
func _jugador():
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	return player

func _mira_derecha():
	return (not animated_sprite.flip_h) == mira_a_la_derecha_por_defecto

func _orientar(dir):
	if dir == 0:
		return
	animated_sprite.flip_h = ((dir > 0) != mira_a_la_derecha_por_defecto)

func _mirar_al_jugador():
	var j = _jugador()
	if j:
		_orientar(sign(j.global_position.x - global_position.x))

func _on_hitbox_body_entered(body):
	if estado == Estado.CAMINAR and body.is_in_group("player"):
		if body.has_method("recibir_dano"):
			body.recibir_dano(1, global_position.x)
		else:
			print("El jefe golpeó a ", body.name)
