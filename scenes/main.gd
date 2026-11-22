extends Node2D

# Cambia esta ruta por la escena del nivel siguiente cuando la tengas lista
const ESCENA_SIGUIENTE = "res://ParadaPelea.tscn"
const DIALOGOS = preload("res://dialogos/ballooon.dialogue")

func _ready() -> void:
	await get_tree().process_frame
	
	# 1. Cámara
	var cam = $Oliver/Camera2D
	cam.enabled = true
	cam.make_current()
	cam.zoom = Vector2(0.525, 0.525)
	cam.offset = Vector2(0, 0)
	cam.limit_left = -95
	cam.limit_right = 1005
	cam.limit_top = -10
	cam.limit_bottom = 642
	
	# 2. Escala y pisada calibrada del Conductor
	$Conductor.scale = Vector2(0.45, 0.45)
	$Conductor/AnimatedSprite2D.scale = Vector2(2.6, 2.6)
	$Conductor/AnimatedSprite2D.position.y = 240
	
	$Conductor.toco_a_oliver.connect(_on_conductor_toco_a_oliver)
	
	# 3. Secuencia cinemática con la burbuja flotando sobre el Conductor
	await get_tree().create_timer(0.8).timeout
	var globo = DialogueManager.show_dialogue_balloon(DIALOGOS, "conductor_camion")
	globo.objetivo_personaje = $Conductor
	globo.desfase_cabeza = Vector2(-55, -65)
	await DialogueManager.dialogue_ended
	$Conductor.empezar_a_correr()

func _on_conductor_toco_a_oliver() -> void:
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
