extends CanvasLayer

@onready var boton_reanudar: Button = $ColorRect/VBoxContainer/BotonReanudar
@onready var boton_menu: Button = $ColorRect/VBoxContainer/BotonMenu

func _ready() -> void:
	# Ocultamos el menú al iniciar el nivel
	hide()
	
	# Conectamos las señales de los botones por código
	boton_reanudar.pressed.connect(_on_boton_reanudar_pressed)
	boton_menu.pressed.connect(_on_boton_menu_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Solo permitimos pausar si NO estamos en el menú principal
		# Asegúrate de que "MenuInicio" sea el nombre exacto de tu nodo raíz en menu_inicio.tscn
		if get_tree().current_scene.name != "MenuInicio":
			alternar_pausa()

func alternar_pausa() -> void:
	# Invertimos el estado actual de pausa
	var nuevo_estado: bool = not get_tree().paused
	get_tree().paused = nuevo_estado
	visible = nuevo_estado
	
	# Si pausamos, le damos el foco al botón para poder usar Enter/Espacio
	if visible:
		boton_reanudar.grab_focus()

func _on_boton_reanudar_pressed() -> void:
	alternar_pausa()

func _on_boton_menu_pressed() -> void:
	# 1. Quitamos la pausa del juego
	get_tree().paused = false
	
	# 2. OCULTAMOS la pantalla oscura y los botones
	hide() 
	
	# 3. Viajamos al menú principal
	get_tree().change_scene_to_file("res://menu_inicio.tscn")
