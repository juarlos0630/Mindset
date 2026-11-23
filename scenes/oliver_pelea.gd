extends "res://scripts/player.gd"   # <- pon aquí TU ruta

@export var vida_maxima: int = 100
var vida: int = 100
var recibiendo_dano: bool = false
var esta_muerto: bool = false

# --- Nodos de UI en ParadaPelea ---
@onready var barra_vida: AnimatedSprite2D = $"../CanvasLayer/BarraVida"
@onready var barra_dash: AnimatedSprite2D = $"../CanvasLayer/BarraDash"
@onready var game_over_screen: TextureRect = $"../CanvasLayer/GameOverScreen"

# --- Contadores de vida y dash ---
var golpes_recibidos: int = 0

@export var dashes_maximos: int = 5
@export var tiempo_recarga_dash: float = 5.0
var dashes_disponibles: int = 5
var timer_recarga_dash: float = 0.0


func _ready() -> void:
	super._ready()
	vida = vida_maxima
	dashes_disponibles = dashes_maximos
	
	if barra_vida:
		barra_vida.frame = 0
	if barra_dash:
		barra_dash.frame = 0
	if game_over_screen:
		game_over_screen.modulate.a = 0.0
		game_over_screen.visible = false


func _physics_process(delta: float) -> void:
	# Recarga gradual del dash (cada 5 segundos recupera 1 carga hasta llegar a 5)
	if dashes_disponibles < dashes_maximos:
		timer_recarga_dash += delta
		if timer_recarga_dash >= tiempo_recarga_dash:
			timer_recarga_dash = 0.0
			dashes_disponibles += 1
			actualizar_barra_dash()
	else:
		timer_recarga_dash = 0.0

	# Mientras recibe daño o ya murió, no se pisa la animación ni se acepta input
	if esta_muerto or recibiendo_dano:
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		move_and_slide()
		return
		
	super._physics_process(delta)


# Sobrescribimos start_dash() de player.gd para interceptar el inicio real del dash
func start_dash() -> void:
	if dashes_disponibles <= 0:
		return
	
	super.start_dash()
	dashes_disponibles -= 1
	actualizar_barra_dash()


func actualizar_barra_dash() -> void:
	if not barra_dash:
		return
	# 5 disponibles -> frame 0 | 4 -> frame 1 | 3 -> frame 2 | 2 -> frame 3 | 1 -> frame 4 | 0 -> frame 5
	var nuevo_frame: int = dashes_maximos - dashes_disponibles
	barra_dash.frame = clamp(nuevo_frame, 0, 5)


func recibir_dano(cantidad: int, desde_x = null) -> void:
	if recibiendo_dano or esta_muerto:
		return
	vida -= cantidad
	golpes_recibidos += 1
	actualizar_barra_vida()
	
	recibiendo_dano = true
	is_attacking = false
	is_dashing = false
	animated_sprite.play("dano_oliver")
	await get_tree().create_timer(0.4).timeout
	recibiendo_dano = false
	
	if vida <= 0:
		mostrar_game_over()


func actualizar_barra_vida() -> void:
	if not barra_vida:
		return
	var nuevo_frame: int = golpes_recibidos / 2
	barra_vida.frame = clamp(nuevo_frame, 0, 4)


func mostrar_game_over() -> void:
	if esta_muerto:
		return
	esta_muerto = true
	
	if is_time_slowed:
		deactivate_bullet_time()
	
	if game_over_screen:
		game_over_screen.visible = true
		var tween := create_tween()
		tween.tween_property(game_over_screen, "modulate:a", 1.0, 1.5)
		await tween.finished
	
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://menu_inicio.tscn")
