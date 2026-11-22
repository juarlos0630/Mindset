extends CanvasLayer

@export var dialogue_resource: DialogueResource
@export var start_from_cue: String = ""
@export var auto_start: bool = false
@export var will_block_other_input: bool = false
@export var next_action: StringName = &"ui_accept"
@export var skip_action: StringName = &"ui_cancel"
@export var tiempo_lectura: float = 2.2

@onready var audio_stream_player: AudioStreamPlayer = %AudioStreamPlayer

var temporary_game_states: Array = []
var is_waiting_for_input: bool = false
var will_hide_balloon: bool = false
var locals: Dictionary = {}
var _locale: String = TranslationServer.get_locale()

var objetivo_personaje: Node2D = null
var desfase_cabeza: Vector2 = Vector2(-100, -100)

var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			if owner == null:
				queue_free()
			else:
				hide()
	get:
		return dialogue_line

var mutation_cooldown: Timer = Timer.new()

@onready var balloon: Control = %Balloon
@onready var character_label: RichTextLabel = %CharacterLabel
@onready var dialogue_label: DialogueLabel = %DialogueLabel
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu
@onready var progress: Polygon2D = %Progress


func _ready() -> void:
	balloon.hide()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)

	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)

	# --- ESTILO DE PASTILLA COMPACTA ---
	var margin: MarginContainer = $Balloon/MarginContainer
	margin.anchor_left = 0.0
	margin.anchor_top = 0.0
	margin.anchor_right = 0.0
	margin.anchor_bottom = 0.0
	margin.offset_left = 0
	margin.offset_top = 0
	margin.offset_right = 215
	margin.offset_bottom = 34
	margin.custom_minimum_size = Vector2(215, 34)
	margin.size = Vector2(215, 34)

	var inner_margin: MarginContainer = $Balloon/MarginContainer/PanelContainer/MarginContainer
	inner_margin.add_theme_constant_override("margin_left", 10)
	inner_margin.add_theme_constant_override("margin_right", 10)
	inner_margin.add_theme_constant_override("margin_top", 4)
	inner_margin.add_theme_constant_override("margin_bottom", 4)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.06, 0.06, 0.09, 0.9)
	estilo.set_corner_radius_all(17)
	estilo.set_border_width_all(2)
	estilo.border_color = Color(1, 1, 1, 0.95)
	$Balloon/MarginContainer/PanelContainer.add_theme_stylebox_override("panel", estilo)

	dialogue_label.add_theme_font_size_override("normal_font_size", 8)
	dialogue_label.add_theme_font_size_override("bold_font_size", 8)
	dialogue_label.add_theme_constant_override("line_separation", 1)
	
	margin.scale = Vector2(0.85, 0.85)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# -----------------------------------

	if auto_start:
		if not is_instance_valid(dialogue_resource):
			assert(false, DMConstants.get_error_message(DMConstants.ERR_MISSING_RESOURCE_FOR_AUTOSTART))
		start()


func _process(_delta: float) -> void:
	# Ocultamos el triángulo indicador ya que el diálogo avanza solo
	progress.visible = false

	if is_instance_valid(objetivo_personaje):
		var margin: MarginContainer = $Balloon/MarginContainer
		margin.size = Vector2(215, 34)
		var pos_pantalla: Vector2 = objetivo_personaje.get_global_transform_with_canvas().origin
		margin.global_position = pos_pantalla + desfase_cabeza


func _unhandled_input(_event: InputEvent) -> void:
	if will_block_other_input:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _locale != TranslationServer.get_locale() and is_instance_valid(dialogue_label):
		_locale = TranslationServer.get_locale()
		var visible_ratio: float = dialogue_label.visible_ratio
		await dialogue_line.refresh()
		if visible_ratio < 1:
			dialogue_label.skip_typing()


func start(with_dialogue_resource: DialogueResource = null, cue: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	if not cue.is_empty():
		start_from_cue = cue
	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_cue, temporary_game_states)
	show()


func apply_dialogue_line() -> void:
	mutation_cooldown.stop()

	progress.hide()
	is_waiting_for_input = false
	balloon.focus_mode = Control.FOCUS_NONE

	character_label.hide()
	character_label.text = tr(dialogue_line.character, "dialogue")

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses

	balloon.show()
	will_hide_balloon = false

	dialogue_label.show()
	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	if dialogue_line.has_tag("voice"):
		audio_stream_player.stream = load(dialogue_line.get_tag_value("voice"))
		audio_stream_player.play()
		await audio_stream_player.finished
		next(dialogue_line.next_id)
	elif dialogue_line.responses.size() > 0:
		responses_menu.show()
		responses_menu.focus_first_item()
	else:
		# Espera automáticamente los segundos configurados y cierra/avanza solo
		var espera: float = tiempo_lectura if dialogue_line.time == "" else dialogue_line.time.to_float()
		await get_tree().create_timer(espera).timeout
		next(dialogue_line.next_id)


func next(next_id: String) -> void:
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		balloon.hide()


func _on_mutated(mutation: Dictionary) -> void:
	if not mutation.is_inline:
		is_waiting_for_input = false
		will_hide_balloon = true
		mutation_cooldown.start(0.1)


func _on_balloon_gui_input(event: InputEvent) -> void:
	if dialogue_label.is_typing:
		var mouse_was_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		var skip_button_was_pressed: bool = event.is_action_pressed(skip_action)
		if mouse_was_clicked or skip_button_was_pressed:
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	next(response.next_id)
