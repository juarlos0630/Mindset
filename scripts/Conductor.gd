extends CharacterBody2D

signal toco_a_oliver

@export var velocidad_carrera: float = 280.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var corriendo: bool = false
var ya_choco: bool = false
var player: Node2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("jefe")
	player = get_tree().get_first_node_in_group("player")
	animated_sprite.play("idle")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if corriendo and not ya_choco and player:
		var dir = sign(player.global_position.x - global_position.x)
		velocity.x = dir * velocidad_carrera
		animated_sprite.flip_h = (dir < 0)
		
		# Si ya está muy cerca de Oliver, disparamos la transición
		if abs(player.global_position.x - global_position.x) < 60.0:
			_activar_transicion()
	else:
		velocity.x = 0.0

	move_and_slide()

	# También detectamos si chocó físicamente con Oliver mediante move_and_slide
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		if col.get_collider() == player and corriendo and not ya_choco:
			_activar_transicion()

func empezar_a_correr() -> void:
	corriendo = true
	animated_sprite.play("correr")

func _activar_transicion() -> void:
	ya_choco = true
	corriendo = false
	velocity.x = 0.0
	toco_a_oliver.emit()
