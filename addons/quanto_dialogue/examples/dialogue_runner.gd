@tool
class_name DialogueRunner
extends Control
## In-game usage example. Attach to a Control node and call start().
##
## Text comes from a TextMapStore (default: the shared one). To preview unsaved text,
## pass your own resolver to start().
##
## Supports [w=0.8] (or [w=0.8][/w]) to pause the typewriter for 0.8 seconds,
## plus any built-in BBCode such as [shake rate=20 level=6]text[/shake].
##
## Errors (from this runner or the interpreter) are logged and shown in the dialog.
## An error opens the UI like a normal timeline (timeline_started), and closing it
## emits timeline_finished, so panel/bars animations and player locking stay in sync.
signal timeline_finished
signal timeline_started
## Fired when the timeline reaches an Event node (e.g. key "color_return", value "half").
signal event_fired(key: String, value: String)

@export var dialog_resource: DialogueDataResource
@export var typewriter_config: TypewriterConfig = TypewriterConfig.new()

## Where text is looked up. Null = TextMapStore.shared().
var text_store: TextMapStore = null

var interpreter := DialogueInterpreter.new()
@onready var choices_container: VBoxContainer = %ChoicesContainer
@onready var speaker_label: Label = %SpeakerLabel
@onready var typewriter_label: RichTextLabel = %TypewriterLabel
@onready var typewriter_timer: Timer = %TypewriterTimer
@onready var typewriter_player: AudioStreamPlayer = %TypewriterPlayer
@onready var finish_player: AudioStreamPlayer = %FinishPlayer
@export var action_name: String = "ui_accept"

## How long to keep the UI visible after a timeline finishes, so close animations can play.
@export var close_delay: float = 0.5
var _close_id: int = 0

var _open := false  # true while the dialog UI is open (timeline or error)
var _showing_error := false
var _full_text: String = ""
var _parsed_text: String = ""
var _char_index: int = 0
var _total_chars: int = 0
var _sound_counter: int = 0
var _scale_fx := ScaleInEffect.new()
var _owned_resolver: TimelineTextResolver = null  # created by start(); released when done

# Matches [w=0.8] and also [w=0.8][/w]
var _wait_regex := RegEx.create_from_string("\\[w=([0-9]*\\.?[0-9]+)\\](?:\\[/w\\])?")
var _tag_regex := RegEx.create_from_string("\\[[^\\]]*\\]")
var _waits: Dictionary = {}  # visible char index -> seconds to pause BEFORE that char


## Returns the first DialogueRunner in the scene tree, or null if there is none.
## Usage: var runner := DialogueRunner.find(self)
static func find(from: Node) -> DialogueRunner:
	if from == null or not from.is_inside_tree():
		return null
	return from.get_tree().get_first_node_in_group("dialogue_runner") as DialogueRunner


func _ready() -> void:
	
	
	visible = false
	_scale_fx.font_size = typewriter_label.get_theme_font_size("normal_font_size") || 16
	typewriter_label.custom_effects.clear()
	typewriter_label.install_effect(_scale_fx)
	if typewriter_config != null and typewriter_config.type_sound != null:
		typewriter_player.stream = typewriter_config.type_sound
	interpreter.line_shown.connect(_on_line)
	interpreter.choices_shown.connect(_on_choices)
	interpreter.event_fired.connect(func(key: String, value: String): event_fired.emit(key, value))
	interpreter.error_raised.connect(show_error)
	interpreter.finished.connect(_on_timeline_finished)
	interpreter.started.connect(_on_timeline_started)
	typewriter_timer.timeout.connect(_on_typewriter_timer)
	interpreter.event_fired.connect(func(key: String, value: String): print("EVENT fired: ", key, " = ", value); event_fired.emit(key, value))

func _exit_tree() -> void:
	_release_resolver()


func _get_step_time() -> float:
	var cps := 30.0
	if typewriter_config != null:
		cps = typewriter_config.characters_per_second
	return 1.0 / maxf(cps, 1.0)

func start(resource: DialogueDataResource, resolver: TextResolver = null) -> void:
	if resource == null:
		push_error("DialogueRunner: Failed to load dialogue resource")
		show_error("Failed to load dialogue resource")
		return
	_release_resolver()
	_showing_error = false
	if resolver == null:
		var store := text_store if text_store != null else TextMapStore.shared()
		_owned_resolver = TimelineTextResolver.new(store, resource.map_id, resource.imports)
		resolver = _owned_resolver
	typewriter_timer.wait_time = _get_step_time()
	# Let the opening input event finish before the first step runs.
	await get_tree().process_frame
	interpreter.start(resource, resolver)
	
## Shows an error in the dialogue box instead of a line, so a failure is visible in game
## (e.g. "Unknown timeline 'intro'"). Press the action key to close it.
## The next start() replaces it.
func show_error(message: String) -> void:
	# Called from another node's _ready(), this node's @onready labels may not exist yet.
	if not is_node_ready():
		await ready
	_close_id += 1  # cancel any pending hide
	show()
	typewriter_timer.stop()
	_clear_buttons()
	_showing_error = true
	speaker_label.text = "ERROR"
	typewriter_label.text = "[color=red]%s[/color]\n\n[color=gray](press to close)[/color]" % message.replace("[", "[lb]")
	typewriter_label.visible_characters = -1
	_char_index = 0
	_total_chars = 0
	# Open the panel and bars if no timeline had already opened them.
	if not _open:
		_open = true
		timeline_started.emit()


func _close_error() -> void:
	_showing_error = false
	_open = false
	_clear_buttons()
	timeline_finished.emit()  # panel and bars slide out, player unlocks
	_close_id += 1
	var id := _close_id
	await get_tree().create_timer(close_delay).timeout
	if id != _close_id:
		return  # something new opened in the meantime
	visible = false
	typewriter_label.text = ""
	speaker_label.text = ""


func _release_resolver() -> void:
	if is_instance_valid(_owned_resolver):
		_owned_resolver.release()
	_owned_resolver = null


func _unhandled_input(event: InputEvent) -> void:
	if _showing_error:
		if event.is_action_pressed(action_name):
			get_viewport().set_input_as_handled()
			_close_error()
		return  # nothing is running; don't advance the interpreter
	if event.is_action_pressed(action_name):
		if _char_index >= _total_chars:
			interpreter.advance()
		elif typewriter_config != null and typewriter_config.allow_skip:
			_on_skip()


func _on_timeline_started(timeline: String) -> void:
	_close_id += 1  # cancels any pending hide from a previous timeline
	_open = true
	visible = true
	timeline_started.emit()


func _on_timeline_finished(timeline: String) -> void:
	_release_resolver()
	if _showing_error:
		return  # the error box stays; closing it emits timeline_finished
	_open = false
	_clear_buttons()
	timeline_finished.emit()  # bars and panel start animating out
	_close_id += 1
	var id := _close_id
	await get_tree().create_timer(close_delay).timeout
	if id != _close_id:
		return  # a new timeline started in the meantime
	visible = false
	typewriter_label.text = ""


func _on_typewriter_finished() -> void:
	finish_player.play()


func _on_skip() -> void:
	typewriter_timer.stop()
	_waits.clear()  # skipping ignores any pending waits
	for i in range(_char_index, _total_chars):
		_scale_fx.reveal_times[i] = 0
	_char_index = _total_chars
	typewriter_label.visible_characters = _char_index
	_on_typewriter_finished()


## Removes [w=x] tags from the text and records, for each one, the visible
## character index it sits in front of.
func _extract_waits(text: String) -> String:
	_waits.clear()
	var before := ""
	var last := 0
	for m in _wait_regex.search_all(text):
		before += text.substr(last, m.get_start() - last)
		var idx := _visible_length(before)
		_waits[idx] = _waits.get(idx, 0.0) + m.get_string(1).to_float()
		last = m.get_end()
	return _wait_regex.sub(text, "", true)


## Counts characters that actually show up (ignores BBCode tags).
func _visible_length(bbcode: String) -> int:
	var s := bbcode.replace("[lb]", "(").replace("[rb]", ")")
	return _tag_regex.sub(s, "", true).length()


func _on_line(speaker: String, text: String, _text_id: String) -> void:
	speaker_label.text = "???" if speaker.is_empty() else speaker
	_full_text = _extract_waits(text)
	_scale_fx.reset()
	typewriter_label.text = "[scale_in]%s[/scale_in]" % _full_text
	typewriter_label.visible_characters = 0
	_total_chars = typewriter_label.get_total_character_count()
	_parsed_text = typewriter_label.get_parsed_text()
	_sound_counter = 0
	_char_index = 0
	_clear_buttons()
	typewriter_timer.wait_time = _get_step_time()
	typewriter_timer.start()


func _on_choices(options: Array) -> void:
	typewriter_label.text = ""
	_clear_buttons()
	for i in options.size():
		_add_button(options[i], interpreter.choose_option.bind(i))


func _add_button(text: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	choices_container.add_child(b)


func _clear_buttons() -> void:
	for c in choices_container.get_children():
		choices_container.remove_child(c)
		c.queue_free()


func _play_type_sound(index: int) -> void:
	# No blip for spaces/newlines, otherwise the first char after a [w] pause often "clicks" on nothing.
	if index < _parsed_text.length() and _parsed_text[index].strip_edges().is_empty():
		return
	var every := 1
	if typewriter_config != null:
		every = maxi(typewriter_config.characters_per_sound, 1)
	if _sound_counter % every == 0:
		typewriter_player.play()
	_sound_counter += 1


func _on_typewriter_timer() -> void:
	typewriter_timer.wait_time = _get_step_time()  # reset after any wait
	if _waits.has(_char_index):
		var w: float = _waits[_char_index]
		_waits.erase(_char_index)
		typewriter_timer.start(w)  # pause; next tick reveals the character
		return
	_scale_fx.mark_revealed(_char_index)
	var revealed := _char_index
	_char_index += 1
	typewriter_label.visible_characters = _char_index
	_play_type_sound(revealed)
	if _char_index >= _total_chars:
		typewriter_timer.stop()
		_on_typewriter_finished()
