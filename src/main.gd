extends PanelContainer

const APP_NAME: String = "Pomodachi"
const PATH_SETTINGS: String = "user://settings"
const PATH_SOUNDS: String = "res://sounds/"

const WINDOW_SIZE_DEFAULT: Vector2i = Vector2i(220, 160)
const WINDOW_SIZE_RUNNING: Vector2i = Vector2i(220, 120)

const SETTINGS: PackedStringArray =  ["chosen_alarm", "activities"]


@export var settings_menu_button: MenuButton
@export var activity_label: Label
@export var minute_label: Label
@export var second_label: Label
@export var extras_to_hide: Array[Control]
@export var stop_button: Button
@export var preset_hbox: HBoxContainer
@export var bottom_hbox: HBoxContainer
@export var activity_option_button: OptionButton # TODO: Allow user to add activities
@export var audio_player: AudioStreamPlayer


var running: bool = false
var elapsed_time: float = 0

var minutes: int = 25
var seconds: int = 0
var start_minutes: int = 0
var start_seconds: int = 0

var chosen_alarm: String
var alarms: PackedStringArray = []
var activities: PackedStringArray = []

var dragging: bool = false
var drag_offset: Vector2i

var _err: int # Throw-away variable


# --- Main functions ---

func _ready() -> void:
	_set_mode_default()
	update_minutes()
	update_seconds()
	load_settings()
	load_alarms()


func _process(delta: float) -> void:
	if dragging:
		get_window().position = DisplayServer.mouse_get_position() - drag_offset

	if !running: return
	elapsed_time += delta

	if elapsed_time >= 1.0: # Second passed
		elapsed_time -= 1.0
		update_seconds(seconds - 1)
		if minutes + seconds == 0: sound_alarm()


# -- Settings ---

func save_settings() -> void:
	var file: FileAccess = FileAccess.open(PATH_SETTINGS, FileAccess.WRITE)
	var data: Dictionary = {}

	for key: String in SETTINGS: data[key] = get(key)
	_err = file.store_var(data)


func load_settings() -> void:
	if !FileAccess.file_exists(PATH_SETTINGS): return save_settings()
	var file: FileAccess = FileAccess.open(PATH_SETTINGS, FileAccess.READ)
	var data: Dictionary = file.get_var()

	for key: String in data.keys(): set(key, data[key])


# --- Alarm handling ---

func load_alarms() -> void:
	for sound_file_path: String in DirAccess.get_files_at("res://sounds/"):
		if !sound_file_path.ends_with(".import"):
			_err = alarms.append(PATH_SOUNDS + sound_file_path)

	alarms.sort()
	if chosen_alarm.is_empty():
		audio_player.stream = load(alarms[0])
	else:
		audio_player.stream = load(chosen_alarm)


func sound_alarm() -> void:
	audio_player.play()

	running = false
	minutes = start_minutes
	seconds = start_seconds
	stop_button.modulate.a = 1.0

# --- Buttons ---

func _on_start_button_pressed() -> void:
	running = true
	elapsed_time = 0
	start_minutes = minutes
	start_seconds = seconds
	_set_mode_running()


func _on_end_button_pressed() -> void:
	# TODO: Save activity progress (take start time if timer went off,
	#		else take start time and do minus remaining time)

	running = false
	audio_player.stop()
	_set_mode_default()


func _on_time_change_button_pressed(is_minute: bool, is_up: bool) -> void:
	var value: int = 1 if is_up else -1

	if is_minute:
		update_minutes(minutes + value)
	else:
		update_seconds(seconds + value)


func _on_preset_button_pressed(id: int) -> void:
	var preset_button: Button = preset_hbox.get_child(id)
	var splits: PackedStringArray = preset_button.text.split(":")

	update_minutes(int(splits[0]))
	update_seconds(int(splits[1]))


func _on_close_button_pressed() -> void:
	get_tree().quit()


# --- Gui inputs ---

func _on_activity_label_gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton: return
	if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			dragging = true
			drag_offset = get_local_mouse_position()
		else:
			dragging = false


func _on_minute_label_gui_input(event: InputEvent) -> void:
	if !event.is_pressed(): return
	if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP:
		update_minutes(minutes + 1)
	if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN:
		update_minutes(minutes - 1)


func _on_second_label_gui_input(event: InputEvent) -> void:
	if !event.is_pressed(): return
	if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP:
		update_seconds(seconds + 1)
	if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN:
		update_seconds(seconds - 1)


# --- Update times ---

func update_minutes(new_value: int = minutes) -> void:
	minutes = clampi(new_value, 0, 99)
	minute_label.text = "%02d" % minutes

	if minutes + seconds == 0:
		update_seconds(1)


func update_seconds(new_value: int = seconds) -> void:
	if new_value >= 60: # Add a minute
		update_minutes(minutes + 1)
		new_value = 0
	elif new_value < 0 and minutes > 0:
		update_minutes(minutes - 1)
		new_value = 59
	elif new_value == 0 and minutes == 0 and !running:
		new_value = 1

	seconds = clampi(new_value, 0, 59)
	second_label.text = "%02d" % seconds


# --- Helper functions ---

func _set_mode_default() -> void:
	get_window().size = WINDOW_SIZE_DEFAULT

	activity_label.text = APP_NAME
	stop_button.visible = false
	preset_hbox.visible = true
	bottom_hbox.visible = true

	for node: Control in extras_to_hide:
		node.visible = true



func _set_mode_running() -> void:
	var activity_id: int = activity_option_button.get_selected_id()

	get_window().size = WINDOW_SIZE_RUNNING

	activity_label.text = activity_option_button.get_item_text(activity_id)
	stop_button.visible = true
	preset_hbox.visible = false
	bottom_hbox.visible = false
	stop_button.modulate.a = 0.5

	for node: Control in extras_to_hide:
		node.visible = false
