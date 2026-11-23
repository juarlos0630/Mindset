extends Node2D

@onready var seleccion: Sprite2D = $SeleccionMenu
@onready var opciones: Array[Sprite2D] = [
	$LetrasMenu0001, # 0: JUGAR
	$LetrasMenu0002, # 1: CARGAR PARTIDA
	$LetrasMenu0003, # 2: OPCIONES
	$LetrasMenu0004  # 3: SALIR
]
@onready var marcadores_boleto: Array[Marker2D] = [
	$PosBoleto0, # JUGAR
	$PosBoleto1, # CARGAR PARTIDA
	$PosBoleto2, # OPCIONES
	$PosBoleto3  # SALIR
]
@onready var oliver: Node2D = $Oliver

var indice_actual: int = 0

# Configuración de caminata de Oliver en el fondo
var velocidad_oliver: float = 45.0
var limite_izquierdo: float = 340.0
var limite_derecho: float = 950.0
var direccion_oliver: int = 1
var anim_oliver: AnimatedSprite2D = null
var anim_player_oliver: AnimationPlayer = null


func _ready() -> void:
	actualizar_posicion_boleto()
	iniciar_caminata_oliver()


func _process(delta: float) -> void:
	mover_oliver_fondo(delta)


func _unhandled_input(event: InputEvent) -> void:
	# 1. Navegación con teclado (Arriba / Abajo / W / S)
	if event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and event.keycode == KEY_S):
		indice_actual = (indice_actual + 1) % opciones.size()
		actualizar_posicion_boleto()
	elif event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and event.keycode == KEY_W):
		indice_actual = (indice_actual - 1 + opciones.size()) % opciones.size()
		actualizar_posicion_boleto()
	elif event.is_action_pressed("ui_accept"):
		ejecutar_opcion()

	# 2. Detección con el mouse (hover y clic)
	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = get_global_mouse_position()
		for i in range(opciones.size()):
			if esta_mouse_sobre_sprite(opciones[i], mouse_pos):
				if indice_actual != i:
					indice_actual = i
					actualizar_posicion_boleto()
				break

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos: Vector2 = get_global_mouse_position()
		for i in range(opciones.size()):
			if esta_mouse_sobre_sprite(opciones[i], mouse_pos):
				indice_actual = i
				ejecutar_opcion()
				break


func actualizar_posicion_boleto() -> void:
	seleccion.global_position = marcadores_boleto[indice_actual].global_position


func esta_mouse_sobre_sprite(sprite: Sprite2D, mouse_pos: Vector2) -> bool:
	var idx: int = opciones.find(sprite)
	if idx == -1:
		return false
	var anchos: Array[float] = [180.0, 440.0, 250.0, 160.0]
	var pos_izq: Vector2 = marcadores_boleto[idx].global_position
	var rect := Rect2(pos_izq.x, pos_izq.y - 25.0, anchos[idx] + 40.0, 50.0)
	return rect.has_point(mouse_pos)


func ejecutar_opcion() -> void:
	match indice_actual:
		0: # JUGAR -> Inicia la escena de City
			get_tree().change_scene_to_file("res://EscenaComic.tscn")
		1: # CARGAR PARTIDA
			cargar_estado_juego()
			print("Cargar partida seleccionado")
		2: # OPCIONES
			print("Opciones seleccionado")
		3: # SALIR
			get_tree().quit()


func iniciar_caminata_oliver() -> void:
	if not is_instance_valid(oliver):
		return
	
	# 1. Apaga cualquier Camera2D dentro de Oliver (incluso si es nieto)
	for cam in oliver.find_children("*", "Camera2D", true, false):
		cam.enabled = false
	
	# 2. Busca AnimatedSprite2D en cualquier nivel interno de Oliver
	var anims := oliver.find_children("*", "AnimatedSprite2D", true, false)
	if anims.size() > 0:
		anim_oliver = anims[0]
		if anim_oliver.sprite_frames:
			var lista: PackedStringArray = anim_oliver.sprite_frames.get_animation_names()
			print("Animaciones en Oliver (AnimatedSprite2D): ", lista)
			for nombre in ["walk", "caminar", "run", "correr", "move", "andar"]:
				if lista.has(nombre):
					anim_oliver.play(nombre)
					return
			for nombre in lista:
				var n := nombre.to_lower()
				if "walk" in n or "camin" in n or "run" in n or "corr" in n:
					anim_oliver.play(nombre)
					return
	
	# 3. Si Oliver usa AnimationPlayer en vez de AnimatedSprite2D
	var players := oliver.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		anim_player_oliver = players[0]
		var lista_ap: PackedStringArray = anim_player_oliver.get_animation_list()
		print("Animaciones en Oliver (AnimationPlayer): ", lista_ap)
		for nombre in lista_ap:
			var n := nombre.to_lower()
			if "walk" in n or "camin" in n or "run" in n or "corr" in n:
				anim_player_oliver.play(nombre)
				return


func mover_oliver_fondo(delta: float) -> void:
	if not is_instance_valid(oliver):
		return
	oliver.position.x += velocidad_oliver * direccion_oliver * delta
	
	if oliver.position.x >= limite_derecho:
		direccion_oliver = -1
		if anim_oliver:
			anim_oliver.flip_h = true
		elif anim_player_oliver:
			oliver.scale.x = -abs(oliver.scale.x)
	elif oliver.position.x <= limite_izquierdo:
		direccion_oliver = 1
		if anim_oliver:
			anim_oliver.flip_h = false
		elif anim_player_oliver:
			oliver.scale.x = abs(oliver.scale.x)

# FUNCIÓN PARA CARGAR PARTIDA 
func cargar_estado_juego() -> void:
	# La ruta 'user://' es la carpeta segura donde Godot guarda los datos en cualquier sistema operativo
	var ruta_guardado = "user://partida_oliver.save"
	
	if FileAccess.file_exists(ruta_guardado):
		var archivo = FileAccess.open(ruta_guardado, FileAccess.READ)
		var datos_partida = archivo.get_var() # Recupera el diccionario guardado
		archivo.close()
		
		print("Partida encontrada y cargada: ", datos_partida)
		
		# IMPORTANTE: Aquí pasas los datos a tu Singleton/Autoload (ej. Global.gd)
		# Si tienes un script Global, descomenta la siguiente línea:
		# Global.datos_jugador = datos_partida
		
		# Cambiar a la escena que estaba guardada, o a un nivel por defecto si no existe
		if datos_partida.has("escena_actual"):
			get_tree().change_scene_to_file(datos_partida["escena_actual"])
		else:
			print("El archivo existe pero no tiene escena guardada. Cargando inicio...")
			get_tree().change_scene_to_file("res://EscenaComic.tscn")
			
	else:
		print("No hay partida guardada aún.")
