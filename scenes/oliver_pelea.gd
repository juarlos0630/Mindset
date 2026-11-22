extends "res://scripts/player.gd"   # <- pon aquí TU ruta

@export var vida_maxima: int = 100
var vida: int = 100
var recibiendo_dano: bool = false


func _ready() -> void:
	super._ready()
	vida = vida_maxima


func _physics_process(delta: float) -> void:
	# Mientras recibe daño no se pisa la animación ni se acepta input
	if recibiendo_dano:
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		move_and_slide()
		return
	super._physics_process(delta)


func recibir_dano(cantidad: int) -> void:
	if recibiendo_dano:
		return
	vida -= cantidad
	recibiendo_dano = true
	is_attacking = false
	is_dashing = false
	animated_sprite.play("dano_oliver")
	await get_tree().create_timer(0.4).timeout
	recibiendo_dano = false
	if vida <= 0:
		print("Oliver derrotado")  # aquí pon tu game over
