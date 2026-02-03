class_name PopupWindow
extends Window

signal preset_value_changed(value: int, index: int)
signal closing


@export var label_title: Label

@export_group("Presets")
@export var spinbox_preset_0: SpinBox
@export var spinbox_preset_1: SpinBox
@export var spinbox_preset_2: SpinBox



func _input(event: InputEvent) -> void:
	if event.is_action("ui_close_dialog"): _on_close_button_pressed()


func set_popup_title(new_title: String) -> void:
	label_title.text = new_title
	title = new_title


func _on_close_button_pressed() -> void:
	closing.emit()
	self.queue_free()


# --- Preset functions ---

func _on_preset_spin_box_value_changed(value: float, index: int) -> void:
	preset_value_changed.emit(int(value), index)


func _grab_focus(source: Control) -> void:
	if source is SpinBox:
		var line_edit: LineEdit = (source as SpinBox).get_line_edit()
		line_edit.grab_focus()

