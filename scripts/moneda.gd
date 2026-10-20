extends Area2D

var velocidad = Vector2.ZERO  # la asigna el jefe al lanzarla
var gravedad = ProjectSettings.get_setting("physics/2d/default_gravity")
const VIDA_MAX = 4.0
var vida = 0.0

func _ready():
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	velocidad.y += gravedad * delta
	global_position += velocidad * delta
	rotation += 8.0 * delta  # giro visual
	vida += delta
	if vida >= VIDA_MAX:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("recibir_dano"):
			body.recibir_dano(1)
		else:
			print("¡Moneda golpeó al jugador!")
		queue_free()
	elif not body.is_in_group("jefe"):
		queue_free()  # chocó con el piso o una pared
