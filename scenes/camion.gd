extends Node2D

@export var start_x := 900.0
@export var stop_x := 250.0
@export var speed := 300.0
@export var delay := 1.0
@export var radio_llanta := 24.0

@onready var llantas := [$Llanta_Trasera, $Llanta_Delantera]
var moving := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	position.x = start_x
	await get_tree().create_timer(delay).timeout
	moving = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if moving and position.x != stop_x:
		position.x = move_toward(position.x, stop_x, speed * delta)
		for l in llantas:
			l.rotation += (speed / radio_llanta) * delta
	
