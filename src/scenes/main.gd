extends PanelContainer

const APP_NAME: String = "Pomodachi"
const PATH_SETTINGS: String = "user://settings"
const PATH_PROGRESS: String = "user://progress"
const PATH_SOUNDS: String = "res://sounds/"

const WINDOW_SIZE_DEFAULT: Vector2i = Vector2i(220, 160)
const WINDOW_SIZE_RUNNING: Vector2i = Vector2i(220, 120)

const SETTINGS: PackedStringArray =  ["chosen_alarm", "activities", "presets"]


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
var run_time: int = 0

var minutes: int = 25
var seconds: int = 0
var start_minutes: int = 0
var start_seconds: int = 0

var chosen_alarm: String
var chosen_activity: String

var alarms: PackedStringArray = []
var presets: PackedInt32Array = [10, 25, 50]
var activities: PackedStringArray = []
var progress: Dictionary[String, int] = {} # { date_time: time_spent }

var dragged_window: Window
var dragging: bool = false
var drag_offset: Vector2i

var open_popup: PopupWindow

var _err: int # Throw-away variable


# --- Main functions ---

func _ready() -> void:
	load_settings()
	load_alarms()
	load_presets()
	load_progress()
	_on_preset_button_pressed(1) # Middle preset is startup default
	_set_mode_default()

	_err = settings_menu_button.get_popup().id_pressed.connect(_on_setting_pressed)


func _input(event: InputEvent) -> void:
	if event.is_action("ui_close_dialog"):
		if open_popup: open_popup.queue_free()
		open_popup = null


func _process(delta: float) -> void:
	if dragging:
		dragged_window.position = DisplayServer.mouse_get_position() - drag_offset

	if !running: return
	elapsed_time += delta

	if elapsed_time >= 1.0: # Second passed
		run_time += 1
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


func _on_setting_pressed(id: int) -> void:
	match id:
		0: open_preset_window() # Change presets
		1: open_activities_window() # Manage activies


# --- Progress tracking ---

func save_progress() -> void:
	var file: FileAccess = FileAccess.open(PATH_PROGRESS, FileAccess.WRITE)
	_err = file.store_var(progress)


func load_progress() -> void:
	if !FileAccess.file_exists(PATH_PROGRESS): return
	var file: FileAccess = FileAccess.open(PATH_PROGRESS, FileAccess.READ)
	progress = file.get_var()


func add_progress() -> void:
	progress[Time.get_datetime_string_from_system()] = run_time
	save_progress()


# --- Buttons ---

func _on_start_button_pressed() -> void:
	running = true
	elapsed_time = 0
	run_time = 0
	start_minutes = minutes
	start_seconds = seconds
	chosen_activity = activities[activity_option_button.get_selected_id()]
	_set_mode_running()


func _on_end_button_pressed() -> void:
	running = false
	audio_player.stop()
	add_progress()
	_set_mode_default()


func _on_time_change_button_pressed(is_minute: bool, is_up: bool) -> void:
	var value: int = 1 if is_up else -1

	if is_minute:
		update_minutes(minutes + value)
	else:
		update_seconds(seconds + value)


func _on_preset_button_pressed(id: int) -> void:
	update_minutes(presets[id])
	update_seconds(0)


func _on_close_button_pressed() -> void:
	get_tree().quit()


# --- Gui inputs ---

func _on_activity_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_detect_drag(event as InputEventMouseButton, get_window())


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


func _detect_drag(event: InputEventMouseButton, window: Window) -> void:
	if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			dragged_window = window
			dragging = true
			drag_offset = window.get_mouse_position()
		else:
			dragging = false


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
	stop_button.modulate.a = 1.0


# -- Preset handling ---

func open_preset_window() -> void:
	var popup: PopupWindow = (load("uid://doxsdtbqopd5s") as PackedScene).instantiate()
	add_child(popup)

	popup.set_popup_title("Presets")
	_err = popup.label_title.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			_detect_drag(event as InputEventMouseButton, popup.get_window()))

	popup.spinbox_preset_0.value = presets[0]
	popup.spinbox_preset_1.value =  presets[1]
	popup.spinbox_preset_2.value =  presets[2]
	popup.visible = true
	open_popup = popup

	_err = popup.preset_value_changed.connect(_on_preset_value_changed)
	_err = popup.closing.connect(save_settings)
	_err = popup.closing.connect(load_presets)
	_err = popup.close_requested.connect(save_settings)
	_err = popup.close_requested.connect(load_presets)


func _on_preset_value_changed(value: int, index: int) -> void:
	presets[index] = clampi(value, 1, 99)


func load_presets() -> void:
	for i: int in 3:
		(preset_hbox.get_child(i) as Button).text = "%02d:00" % presets[i]


# -- Activites handling ---

func open_activities_window() -> void:
	var popup: PopupWindow = (load("uid://drbb04j5raw3u") as PackedScene).instantiate()
	add_child(popup)

	popup.set_popup_title("Activities")
	_err = popup.label_title.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			_detect_drag(event as InputEventMouseButton, popup.get_window()))

	popup.visible = true
	open_popup = popup


# --- Mode setting ---

func _set_mode_default() -> void:
	get_window().size = WINDOW_SIZE_DEFAULT
	get_window().title = APP_NAME
	activity_label.text = APP_NAME

	# Reset time
	minutes = start_minutes
	seconds = start_seconds

	stop_button.visible = false
	stop_button.modulate.a = 1.0

	settings_menu_button.disabled = false
	settings_menu_button.modulate.a = 1.0

	preset_hbox.visible = true
	bottom_hbox.visible = true

	for node: Control in extras_to_hide:
		node.visible = true


func _set_mode_running() -> void:
	var activity_id: int = activity_option_button.get_selected_id()
	var new_title: String = activity_option_button.get_item_text(activity_id)

	get_window().size = WINDOW_SIZE_RUNNING
	get_window().title = new_title
	activity_label.text = new_title

	stop_button.visible = true
	stop_button.modulate.a = 0.5

	settings_menu_button.disabled = true
	settings_menu_button.modulate.a = 0.0

	preset_hbox.visible = false
	bottom_hbox.visible = false

	for node: Control in extras_to_hide:
		node.visible = false
