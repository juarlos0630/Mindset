extends Control

# Arreglo para arrastrar tus 6 imágenes del cómic desde el Inspector
@export var paginas_comic: Array[Texture2D]
# Ruta de la escena de tu primer nivel (ej. res://Niveles/Nivel1.tscn)
@export_file("*.tscn") var ruta_siguiente_nivel: String

var pagina_actual = 0
@onready var visor_comic = $TextureRect

func _ready():
	# Carga la primera página al iniciar la escena
	if paginas_comic.size() > 0:
		visor_comic.texture = paginas_comic[0]

func _input(event):
	# Detecta clic izquierdo o el botón de aceptar (Enter/Espacio)
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		avanzar_pagina()

func avanzar_pagina():
	pagina_actual += 1
	
	# Si aún hay páginas, muestra la siguiente
	if pagina_actual < paginas_comic.size():
		visor_comic.texture = paginas_comic[pagina_actual]
	else:
		# Si se acabaron las páginas, cambia a la escena del juego
		if ruta_siguiente_nivel != "":
			get_tree().change_scene_to_file(ruta_siguiente_nivel)
		else:
			print("Error: No se ha asignado la ruta del siguiente nivel.")
