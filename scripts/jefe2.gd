extends CharacterBody2D

# Jefe 2: la caja de cereales. Estados: pausa, caminar, disparar, recibir daño y muerto.
#
# Animaciones que espera el AnimatedSprite2D (ya vienen en jefe_2_frames.tres):
#   idle, caminar, disparo, dano

signal vida_cambiada(actual, maxima)
signal derrotado

enum Estado { IDLE, CAMINAR, DISPARAR, DANO, MUERTO }

@export var cereal_scene: PackedScene
@export var mira_a_la_derecha_por_defecto = true   # ¿el sprite original mira a la derecha?

@export_group("Vida")
@export var vida_maxima = 10               # 10 golpes para derrotarlo
@export var tiempo_invulnerable = 0.5      # segundos sin poder recibir otro golpe
@export var empuje_al_recibir_dano = 90.0
@export var el_dano_interrumpe_el_disparo = true
@export_file("*.tscn") var escena_al_derrotar = "res://menu_inicio.tscn"

@export_group("Recibir golpes de Oliver")
@export var alcance_recibir_x = 120.0      # distancia horizontal para que el golpe de Oliver conecte
@export var alcance_recibir_y = 95.0       # distancia vertical para que el golpe de Oliver conecte

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

@export_group("Fase 2 (4 golpes restantes)")
@export var golpes_activar_furia_1 = 4
@export var mult_velocidad_furia_1 = 1.75
@export var mult_velocidad_balas_furia_1 = 1.45
@export var mult_animacion_furia_1 = 1.65
@export var disparos_extra_furia_1 = 1
@export var pausa_min_furia_1 = 0.15
@export var pausa_max_furia_1 = 0.35

@export_group("Fase 3 Extrema (2 golpes restantes)")
@export var golpes_activar_furia_2 = 2
@export var mult_velocidad_furia_2 = 2.30
@export var mult_velocidad_balas_furia_2 = 1.85
@export var mult_animacion_furia_2 = 2.15
@export var disparos_extra_furia_2 = 2
@export var pausa_min_furia_2 = 0.05
@export var pausa_max_furia_2 = 0.18

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
var golpe_oliver_registrado = false
var nivel_furia = 0             # 0 = normal, 1 = 4 golpes restantes, 2 = 2 golpes restantes

var player: Node2D = null
var oliver_colision: Node2D = null
var anim_oliver: AnimatedSprite2D = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var mi_colision: CollisionShape2D = $CollisionShape2D
@onready var hitbox = get_node_or_null("Hitbox")
@onready var barra_jefe2: AnimatedSprite2D = get_node_or_null("../CanvasLayer/BarraVidaJefe")
@onready var you_win_screen: TextureRect = get_node_or_null("../CanvasLayer/YouWinScreen")
@onready var game_over_screen: TextureRect = get_node_or_null("../CanvasLayer/GameOverScreen")


func _ready():
	add_to_group("jefe")
	vida = vida_maxima
	if barra_jefe2:
		barra_jefe2.stop()
		barra_jefe2.visible = true
		barra_jefe2.frame = 0
	if you_win_screen:
		you_win_screen.modulate.a = 0.0
		you_win_screen.visible = false
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("dano"):
		animated_sprite.sprite_frames.set_animation_loop("dano", false)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.frame_changed.connect(_on_frame_changed)
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	_buscar_oliver()
	vida_cambiada.emit(vida, vida_maxima)
	_cambiar_estado(Estado.IDLE)


func _buscar_oliver():
	player = get_tree().get_first_node_in_group("player") as Node2D
	if player:
		oliver_colision = player.get_node_or_null("CollisionShape2D") as Node2D
		anim_oliver = player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if player is CharacterBody2D:
			add_collision_exception_with(player)
			player.add_collision_exception_with(self)


func _centro_yo() -> Vector2:
	if mi_colision:
		return mi_colision.global_position
	return global_position


func _centro_oliver() -> Vector2:
	if oliver_colision:
		return oliver_colision.global_position
	if player:
		return player.global_position
	return global_position


func _unhandled_input(event):
	if tecla_prueba_dano and OS.is_debug_build() \
			and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_J:
		recibir_dano(1)


func _physics_process(delta):
	if player == null or not is_instance_valid(player):
		_buscar_oliver()

	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
	if not is_on_floor():
		velocity.y += gravity * delta

	_revisar_golpe_de_oliver()

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


# ---------------------------------------------------------------- detección golpe Oliver
func _oliver_me_mira() -> bool:
	if anim_oliver == null:
		return true
	var yo_a_la_derecha: bool = _centro_yo().x > _centro_oliver().x
	var oliver_mira_derecha: bool = not anim_oliver.flip_h
	return yo_a_la_derecha == oliver_mira_derecha


func _revisar_golpe_de_oliver():
	if anim_oliver == null or anim_oliver.animation != "attack":
		golpe_oliver_registrado = false
		return
	if golpe_oliver_registrado or invulnerable_timer > 0.0 or estado == Estado.DANO or estado == Estado.MUERTO:
		return

	var diff: Vector2 = _centro_yo() - _centro_oliver()
	if absf(diff.x) <= alcance_recibir_x and absf(diff.y) <= alcance_recibir_y and _oliver_me_mira():
		golpe_oliver_registrado = true
		recibir_dano(1, _centro_oliver().x)


# ---------------------------------------------------------------- estados
func _cambiar_estado(nuevo):
	estado = nuevo
	match nivel_furia:
		2:
			animated_sprite.speed_scale = mult_animacion_furia_2
		1:
			animated_sprite.speed_scale = mult_animacion_furia_1
		_:
			animated_sprite.speed_scale = 1.0

	match nuevo:
		Estado.IDLE:
			var p_min = pausa_min
			var p_max = pausa_max
			if nivel_furia == 2:
				p_min = pausa_min_furia_2
				p_max = pausa_max_furia_2
			elif nivel_furia == 1:
				p_min = pausa_min_furia_1
				p_max = pausa_max_furia_1
			timer = randf_range(p_min, p_max)
			velocity.x = 0.0
			_reproducir("idle")
		Estado.CAMINAR:
			timer = tiempo_max_caminar
			_elegir_destino()
			_reproducir("caminar")
		Estado.DISPARAR:
			var extra = 0
			if nivel_furia == 2:
				extra = disparos_extra_furia_2
			elif nivel_furia == 1:
				extra = disparos_extra_furia_1
			var rafaga = disparos_por_rafaga + extra
			timer = 1.5 * rafaga + 1.0
			velocity.x = 0.0
			rafaga_restante = rafaga
			_mirar_al_jugador()
			_reproducir("disparo")
		Estado.DANO:
			animated_sprite.speed_scale = 1.0
			timer = 0.6
			_reproducir("dano")


func _elegir_siguiente_patron():
	var j = _jugador()
	if j and abs(j.global_position.x - global_position.x) > rango_disparo:
		ultimo_patron = Estado.CAMINAR
		_cambiar_estado(Estado.CAMINAR)
		return
	var opciones = [Estado.DISPARAR, Estado.DISPARAR, Estado.CAMINAR]
	if ultimo_patron == Estado.CAMINAR:
		opciones = [Estado.DISPARAR]
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
		var lado = sign(global_position.x - j.global_position.x)
		if lado == 0.0:
			lado = 1.0
		objetivo_x = j.global_position.x + lado * rango_disparo * 0.8
	else:
		if abs(global_position.x - limite_izquierdo) < abs(global_position.x - limite_derecho):
			objetivo_x = limite_derecho
		else:
			objetivo_x = limite_izquierdo
	objetivo_x = clamp(objetivo_x, limite_izquierdo, limite_derecho)


func _proceso_caminar(delta):
	timer -= delta
	var mult_vel = 1.0
	if nivel_furia == 2:
		mult_vel = mult_velocidad_furia_2
	elif nivel_furia == 1:
		mult_vel = mult_velocidad_furia_1
	var vel_actual = velocidad_caminar * mult_vel

	var dx = objetivo_x - global_position.x
	if abs(dx) <= max(8.0, vel_actual * delta) or timer <= 0.0 or is_on_wall():
		_cambiar_estado(Estado.IDLE)
		return
	var dir = sign(dx)
	velocity.x = dir * vel_actual
	_orientar(dir)


# --- DISPARAR
func _proceso_disparar(delta):
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	timer -= delta
	if timer <= 0.0:
		_cambiar_estado(Estado.IDLE)


func _on_frame_changed():
	if estado == Estado.DISPARAR and animated_sprite.animation == "disparo" \
			and animated_sprite.frame == frame_disparo:
		_lanzar_cereal()


func _lanzar_cereal():
	if cereal_scene == null:
		push_warning("Falta asignar Cereal Scene en el Inspector del jefe.")
		return
	var lado = 1.0 if _mira_derecha() else -1.0
	var origen = animated_sprite.to_global(Vector2(MANO_DISPARO.x * lado, MANO_DISPARO.y))

	var objetivo = origen + Vector2(lado * 400.0, 0.0)
	var j = _jugador()
	if j:
		objetivo = _centro_oliver()
	var dir = (objetivo - origen).normalized()
	dir = dir.rotated(deg_to_rad(randf_range(-dispersion_grados, dispersion_grados)))

	var grande = randf() >= prob_cereal_pequeno
	var mult_balas = 1.0
	if nivel_furia == 2:
		mult_balas = mult_velocidad_balas_furia_2
	elif nivel_furia == 1:
		mult_balas = mult_velocidad_balas_furia_1

	var cereal = cereal_scene.instantiate()
	cereal.grande = grande
	cereal.escala = abs(animated_sprite.global_scale.x) \
		* (escala_cereal_grande if grande else escala_cereal_pequeno)
	cereal.velocidad = dir * (velocidad_cereal_grande if grande else velocidad_cereal_pequeno) * mult_balas
	get_parent().add_child(cereal)
	cereal.global_position = origen


# --- DAÑO Y BARRA DE VIDA
func actualizar_barra_vida():
	if not barra_jefe2:
		return
	var total_frames := 7
	if barra_jefe2.sprite_frames and barra_jefe2.sprite_frames.has_animation(barra_jefe2.animation):
		total_frames = barra_jefe2.sprite_frames.get_frame_count(barra_jefe2.animation)
	var max_idx := maxi(total_frames - 1, 1)
	if vida <= 0:
		barra_jefe2.frame = max_idx
		return
	var proporcion_dano: float = 1.0 - (float(vida) / float(maxi(vida_maxima, 1)))
	barra_jefe2.frame = clampi(int(round(proporcion_dano * float(max_idx))), 0, max_idx)


func _color_base_furia() -> Color:
	if nivel_furia == 2:
		return Color(1.0, 0.45, 0.45)
	elif nivel_furia == 1:
		return Color(1.0, 0.72, 0.72)
	return Color.WHITE


func _verificar_modo_furia():
	if vida <= 0:
		return
	if vida <= golpes_activar_furia_2 and nivel_furia < 2:
		nivel_furia = 2
		animated_sprite.modulate = _color_base_furia()
	elif vida <= golpes_activar_furia_1 and nivel_furia < 1:
		nivel_furia = 1
		animated_sprite.modulate = _color_base_furia()


func recibir_dano(cantidad = 1, desde_x = null):
	if estado == Estado.MUERTO or invulnerable_timer > 0.0:
		return
	vida = max(vida - cantidad, 0)
	actualizar_barra_vida()
	vida_cambiada.emit(vida, vida_maxima)
	if vida <= 0:
		_morir()
		return
	invulnerable_timer = tiempo_invulnerable
	_verificar_modo_furia()

	if estado == Estado.DISPARAR and not el_dano_interrumpe_el_disparo:
		_destello()
		return

	_cambiar_estado(Estado.DANO)
	var lado = -1.0 if _mira_derecha() else 1.0
	if desde_x != null and desde_x != global_position.x:
		lado = sign(global_position.x - desde_x)
	velocity.x = lado * empuje_al_recibir_dano


func _proceso_dano(delta):
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	timer -= delta
	if timer <= 0.0:
		_cambiar_estado(Estado.IDLE)


func _destello():
	var t = create_tween()
	animated_sprite.modulate = Color(1.0, 0.25, 0.25)
	t.tween_property(animated_sprite, "modulate", _color_base_furia(), 0.25)


func _morir():
	estado = Estado.MUERTO
	actualizar_barra_vida()
	collision_layer = 0
	if hitbox:
		hitbox.set_deferred("monitoring", false)
	animated_sprite.visible = false
	Engine.time_scale = 1.0
	derrotado.emit()

	var pantalla_final: TextureRect = you_win_screen if you_win_screen else game_over_screen
	if pantalla_final:
		pantalla_final.visible = true
		var t = create_tween()
		t.tween_property(pantalla_final, "modulate:a", 1.0, 1.5)
		await t.finished
		await get_tree().create_timer(2.0).timeout
	else:
		await get_tree().create_timer(1.5).timeout

	# ruta del comic
	var ruta_comic_siguiente = "res://escena_final_nivel_2.tscn"
	
	# --- 2. GUARDAMOS LA PARTIDA ---
	guardar_partida(ruta_comic_siguiente)

	# --- 3. CAMBIAMOS DE ESCENA ---
	if ResourceLoader.exists(ruta_comic_siguiente):
		get_tree().change_scene_to_file(ruta_comic_siguiente)
	elif escena_al_derrotar != "" and ResourceLoader.exists(escena_al_derrotar):
		# Respaldo de seguridad por si acaso la escena del cómic no se encuentra
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
				animated_sprite.play("disparo")
			else:
				_cambiar_estado(Estado.IDLE)
		"dano":
			if estado == Estado.DANO:
				_cambiar_estado(Estado.IDLE)


func _reproducir(nombre):
	var frames = animated_sprite.sprite_frames
	if frames and frames.has_animation(nombre) and frames.get_frame_count(nombre) > 0:
		animated_sprite.play(nombre)


# ---------------------------------------------------------------- utilidades
func _jugador():
	if player == null or not is_instance_valid(player):
		_buscar_oliver()
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

func guardar_partida(ruta_escena: String) -> void:
	var datos_partida = {
		"escena_actual": ruta_escena
	}
	
	var archivo = FileAccess.open("user://partida_oliver.save", FileAccess.WRITE)
	archivo.store_var(datos_partida)
	archivo.close()
	print("¡Partida guardada exitosamente! Nivel a cargar: ", ruta_escena)
