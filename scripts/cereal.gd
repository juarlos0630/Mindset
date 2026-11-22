extends Area2D

# Proyectil del jefe 2. El jefe fija "grande", "escala" y "velocidad" ANTES de
# agregarlo a la escena. Sus sprites y su colisión se construyen aquí mismo.

@export var carpeta = "res://assets/sprites/jefe_2/cereal/"
@export var generar_migajas = true

var grande = true
var escala = 0.25
var velocidad = Vector2.ZERO
var dano = 1
var gravedad = 0.0            # > 0 si quieres que describa un arco

const VIDA_MAX = 5.0
var vida = 0.0
var sprite: AnimatedSprite2D
var sin_arte = false
var radio = 12.0

func _ready():
	add_to_group("proyectil_jefe")
	var tipo = "grande" if grande else "pequeno"

	# animación: pieza con estela <-> pieza limpia (efecto de velocidad)
	var frames = SpriteFrames.new()
	frames.set_animation_speed("default", 12.0)
	frames.set_animation_loop("default", true)
	for i in range(2):
		var tex = _cargar("cereal_%s_%d.png" % [tipo, i])
		if tex:
			frames.add_frame("default", tex)
	sin_arte = frames.get_frame_count("default") == 0

	# colisión: círculo ajustado a la pieza (tamaño nativo del dibujo * escala)
	radio = (80.0 if grande else 10.0) * escala
	var forma = CircleShape2D.new()
	forma.radius = radio
	var col = CollisionShape2D.new()
	col.shape = forma
	add_child(col)

	if sin_arte:
		push_warning("No se encontraron los sprites del cereal en: " + carpeta)
		queue_redraw()                       # dibuja un círculo de reemplazo
	else:
		sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.scale = Vector2(escala, escala)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		sprite.play("default")

	# orientación: la estela queda siempre atrás y la pieza nunca de cabeza
	if velocidad.x < 0.0:
		if sprite:
			sprite.flip_h = true
		rotation = Vector2(-velocidad.x, velocidad.y).angle()
	else:
		rotation = velocidad.angle()

	body_entered.connect(_on_body_entered)

func _draw():
	if sin_arte:
		draw_circle(Vector2.ZERO, radio, Color("E0A030"))

func _physics_process(delta):
	velocidad.y += gravedad * delta
	global_position += velocidad * delta
	vida += delta
	if vida >= VIDA_MAX:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("jefe") or body.is_in_group("proyectil_jefe"):
		return
	if body.is_in_group("player"):
		if body.has_method("recibir_dano"):
			body.recibir_dano(dano, global_position.x)
		else:
			print("¡Cereal golpeó al jugador!")
	_explotar()

func _explotar():
	set_deferred("monitoring", false)
	set_physics_process(false)
	var padre = get_parent()
	var tex = _cargar("cereal_migaja.png") if generar_migajas else null
	if tex and padre:
		var factor = 1.0 if grande else 0.35
		for i in range(4):
			var m = Sprite2D.new()
			m.texture = tex
			m.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			m.scale = Vector2(escala, escala) * factor * randf_range(0.6, 1.0)
			padre.add_child(m)
			m.global_position = global_position
			var alto = global_position + Vector2(randf_range(-60.0, 60.0), randf_range(-70.0, -20.0)) * (escala / 0.25) * 0.5
			var t = m.create_tween()
			t.tween_property(m, "global_position", alto, 0.22).set_ease(Tween.EASE_OUT)
			t.tween_property(m, "global_position:y", alto.y + 90.0, 0.35).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(m, "modulate:a", 0.0, 0.35)
			t.tween_callback(m.queue_free)
	queue_free()

func _cargar(nombre):
	var ruta = carpeta + nombre
	if ResourceLoader.exists(ruta):
		return load(ruta)
	return null
