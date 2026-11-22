extends Node2D

const ANCHO_ESCENA := 1024.0
const ALTO_ESCENA := 1.0
const CENTRO := Vector2(0.0, 42.0)  # centro de x -512..512 y y -174..258

var camara_fija: Camera2D


func _ready() -> void:
	call_deferred("ajustar_camara")
	get_viewport().size_changed.connect(ajustar_camara)


func ajustar_camara() -> void:
	for cam in get_tree().root.find_children("*", "Camera2D", true, false):
		if cam != camara_fija:
			cam.enabled = false

	if not is_instance_valid(camara_fija):
		camara_fija = Camera2D.new()
		camara_fija.name = "CamaraFijaArena"
		add_child(camara_fija)

	var v: Vector2 = get_viewport_rect().size
	var z: float = min(v.x / ANCHO_ESCENA, v.y / ALTO_ESCENA)
	camara_fija.zoom = Vector2(z, z)
	camara_fija.position = CENTRO
	camara_fija.enabled = true
	camara_fija.make_current()
