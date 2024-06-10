class_name EntryField extends HBoxContainer

@onready var label: Label = $Label

func _process(_delta: float) -> void:
  label.text = name

func set_value(new_value):
  push_error("EntryField.set_value not overridden by ", (get_script() as Script).resource_name)

signal value_changed(new_value)
