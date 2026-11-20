extends Control

# Menú principal de Mindset: "Iniciar juego" y "Salir".
# Toda la interfaz se construye desde este script, así que la escena solo
# necesita un nodo Control raíz con este script.

@export_file("*.tscn") var escena_juego = "res://scenes/main.tscn"
@export_file("*.jpg", "*.png") var fondo_path = "res://assets/backgrounds/fondo_nivel3.jpg"
@export_file("*.ogg", "*.mp3", "*.wav") var musica_path = ""   # opcional: música del menú
@export var titulo = "MINDSET"
@export var subtitulo = "Cinco minutos más"
@export var creditos = "Equipo 6 · ITS Xalapa"
@export var mostrar_personajes = true

const COLOR_FONDO = Color("16162A")
const COLOR_VIOLETA = Color("9D4EDD")
const COLOR_AMBAR = Color("FFA630")
const COLOR_TEXTO = Color("F5F3FA")

var boton_iniciar: Button
var boton_salir: Button
var cortina: ColorRect          # fundido a negro al entrar y al iniciar
var mapple: TextureRect
var mapple_top = 0.0
var mapple_bottom = 0.0
var tiempo = 0.0
var iniciando = false

func _ready():
	Engine.time_scale = 1.0     # por si se vuelve al menú en pleno bullet time
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crear_fondo()
	if mostrar_personajes:
		_crear_personajes()
	_crear_menu()
	_crear_creditos()
	_crear_cortina()
	_crear_musica()

	boton_iniciar.grab_focus.call_deferred()   # navegable con teclado y control
	var t = create_tween()
	t.tween_property(cortina, "color:a", 0.0, 0.6)

func _process(delta):
	tiempo += delta
	if mapple:
		var bob = sin(tiempo * 2.5) * 10.0
		mapple.offset_top = mapple_top + bob
		mapple.offset_bottom = mapple_bottom + bob

# ---------------------------------------------------------------- construcción
func _crear_fondo():
	var base = ColorRect.new()
	base.color = COLOR_FONDO
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var tex = _cargar(fondo_path)
	if tex:
		var fondo = TextureRect.new()
		fondo.texture = tex
		fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fondo)
		fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var velo = ColorRect.new()   # oscurece el fondo para que el texto se lea
	velo.color = Color(0.05, 0.04, 0.12, 0.62)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(velo)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _crear_personajes():
	var vp = get_viewport_rect().size

	var tex_oliver = _cargar("res://assets/sprites/oliver/oliver_idle.png")
	if tex_oliver:
		var alto = vp.y * 0.5
		var ancho = alto * float(tex_oliver.get_width()) / float(tex_oliver.get_height())
		var oliver = _decorado(tex_oliver)
		oliver.anchor_left = 0.0
		oliver.anchor_right = 0.0
		oliver.anchor_top = 1.0
		oliver.anchor_bottom = 1.0
		oliver.offset_left = 40.0
		oliver.offset_right = 40.0 + ancho
		oliver.offset_top = -(16.0 + alto)
		oliver.offset_bottom = -16.0

	var tex_mapple = _cargar("res://assets/sprites/mapple/mapple.png")
	if tex_mapple:
		var lado = vp.y * 0.2
		mapple = _decorado(tex_mapple)
		mapple.anchor_left = 0.0
		mapple.anchor_right = 0.0
		mapple.anchor_top = 1.0
		mapple.anchor_bottom = 1.0
		mapple.offset_left = 40.0 + vp.y * 0.34
		mapple.offset_right = mapple.offset_left + lado
		mapple_top = -(vp.y * 0.5 + 24.0)
		mapple_bottom = mapple_top + lado
		mapple.offset_top = mapple_top
		mapple.offset_bottom = mapple_bottom

func _decorado(tex):
	var r = TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # pixel art nítido
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r

func _crear_menu():
	var centro = CenterContainer.new()
	add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var columna = VBoxContainer.new()
	columna.add_theme_constant_override("separation", 16)
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.add_child(columna)

	var titulo_label = _label(titulo, 104, COLOR_TEXTO)
	columna.add_child(titulo_label)
	var sub_label = _label(subtitulo, 28, COLOR_VIOLETA)
	columna.add_child(sub_label)

	var separador = Control.new()
	separador.custom_minimum_size = Vector2(0, 36)
	columna.add_child(separador)

	boton_iniciar = _boton("Iniciar juego")
	boton_iniciar.pressed.connect(_on_iniciar)
	columna.add_child(boton_iniciar)

	boton_salir = _boton("Salir")
	boton_salir.pressed.connect(_on_salir)
	columna.add_child(boton_salir)

	# suave pulso del título
	var t = create_tween().set_loops()
	t.tween_property(titulo_label, "modulate:a", 0.82, 1.4)
	t.tween_property(titulo_label, "modulate:a", 1.0, 1.4)

func _crear_creditos():
	var l = _label(creditos, 16, Color(COLOR_TEXTO, 0.7))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_constant_override("outline_size", 0)
	add_child(l)
	l.anchor_left = 1.0
	l.anchor_right = 1.0
	l.anchor_top = 1.0
	l.anchor_bottom = 1.0
	l.offset_left = -360.0
	l.offset_right = -16.0
	l.offset_top = -40.0
	l.offset_bottom = -12.0

func _crear_cortina():
	cortina = ColorRect.new()
	cortina.color = Color(0, 0, 0, 1)
	cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cortina)                      # al final: queda por encima de todo
	cortina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _crear_musica():
	var stream = _cargar(musica_path)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	var player = AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.play()

# ---------------------------------------------------------------- utilidades
func _cargar(ruta):
	if ruta != "" and ResourceLoader.exists(ruta):
		return load(ruta)
	return null

func _label(texto, tamano, color):
	var l = Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", COLOR_FONDO)
	l.add_theme_constant_override("outline_size", 10)
	return l

func _estilo(fondo, borde):
	var sb = StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.border_color = borde
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	return sb

func _boton(texto):
	var b = Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(340, 64)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", COLOR_TEXTO)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", COLOR_FONDO)
	var normal = _estilo(Color(0.09, 0.09, 0.17, 0.88), COLOR_VIOLETA)
	var resaltado = _estilo(Color(0.36, 0.17, 0.56, 0.95), COLOR_AMBAR)
	var presionado = _estilo(COLOR_AMBAR, COLOR_AMBAR)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", resaltado)
	b.add_theme_stylebox_override("focus", resaltado)
	b.add_theme_stylebox_override("pressed", presionado)
	b.add_theme_stylebox_override("disabled", normal)
	b.mouse_entered.connect(b.grab_focus)   # el mouse y el teclado comparten selección
	return b

# ---------------------------------------------------------------- acciones
func _on_iniciar():
	if iniciando:
		return
	if not ResourceLoader.exists(escena_juego):
		push_error("No existe la escena del juego: " + escena_juego)
		return
	iniciando = true
	boton_iniciar.disabled = true
	boton_salir.disabled = true
	cortina.mouse_filter = Control.MOUSE_FILTER_STOP
	var t = create_tween()
	t.tween_property(cortina, "color:a", 1.0, 0.45)
	await t.finished
	get_tree().change_scene_to_file(escena_juego)

func _on_salir():
	get_tree().quit()
