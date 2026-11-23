extends Node2D

const ESCENA_SIGUIENTE = "res://scenes/Nivel3/escena_conductor.tscn"
const DIALOGOS = preload("res://dialogos/ballooon.dialogue")

@export var rango_interaccion: float = 220.0

var puede_interactuar: bool = false
var transicionando: bool = false
var indicador_e: PanelContainer
var camion_ref: Node2D
var camion_x_inicial: float = 0.0
var camion_x_anterior: float = 0.0
var camion_ya_llego_al_fondo: bool = false

@onready var oliver: Node2D = $Oliver

func _ready() -> void:
	# 1. Cámara intacta
	var cam = $Oliver/Camera2D2
	cam.enabled = true
	cam.make_current()
	cam.zoom = Vector2(0.92, 0.92)
	cam.offset = Vector2(0, 48)
	cam.limit_bottom = 85
	
	await get_tree().process_frame
	
	camion_ref = find_child("*camion*", true, false)
	if camion_ref == null:
		camion_ref = find_child("*Camion*", true, false)
	
	if camion_ref:
		camion_x_inicial = camion_ref.global_position.x
		camion_x_anterior = camion_x_inicial
	
	_crear_indicador_e()
	
	# 2. Diálogo nuevo flotando arriba de Oliver
	await get_tree().create_timer(0.5).timeout
	var globo = DialogueManager.show_dialogue_balloon(DIALOGOS, "oliver_ciudad")
	globo.objetivo_personaje = oliver
	globo.desfase_cabeza = Vector2(-80, -80)
	await DialogueManager.dialogue_ended
	oliver.set_physics_process(true)

func _process(_delta: float) -> void:
	if transicionando or not oliver or not camion_ref:
		return
	
	var velocidad_camion = abs(camion_ref.global_position.x - camion_x_anterior)
	camion_x_anterior = camion_ref.global_position.x
	
	if abs(camion_ref.global_position.x - camion_x_inicial) > 100.0 and velocidad_camion < 0.2:
		camion_ya_llego_al_fondo = true
	
	if not camion_ya_llego_al_fondo:
		puede_interactuar = false
		indicador_e.visible = false
		return
	
	var distancia_x = abs(oliver.global_position.x - camion_ref.global_position.x)
	if distancia_x <= rango_interaccion:
		puede_interactuar = true
		indicador_e.visible = true
		indicador_e.global_position = camion_ref.global_position + Vector2(-15, -70)
	else:
		puede_interactuar = false
		indicador_e.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if puede_interactuar and not transicionando:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
			_iniciar_transicion()

func _crear_indicador_e() -> void:
	indicador_e = PanelContainer.new()
	var label = Label.new()
	label.text = " E "
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	indicador_e.add_child(label)
	indicador_e.visible = false
	indicador_e.z_index = 20
	add_child(indicador_e)

func _iniciar_transicion() -> void:
	transicionando = true
	indicador_e.visible = false
	
	var canvas = CanvasLayer.new()
	var telon = ColorRect.new()
	telon.color = Color(0, 0, 0, 0)
	telon.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(telon)
	add_child(canvas)
	
	var tween = create_tween()
	tween.tween_property(telon, "color:a", 1.0, 0.7)
	await tween.finished
	get_tree().change_scene_to_file(ESCENA_SIGUIENTE)
