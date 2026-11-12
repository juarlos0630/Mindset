extends Node2D

# Se ejecuta una sola vez al entrar a la escena de la ciudad
func _ready() -> void:
	var cam = $Oliver/Camera2D2
	cam.enabled = true
	cam.make_current()
	print("Cámara activa: ", get_viewport().get_camera_2d().get_path())
	print("Zoom: ", get_viewport().get_camera_2d().zoom)# Cambia 100.0 por el número que prefieras (ej. la mitad de su velocidad normal)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
