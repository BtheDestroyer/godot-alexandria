class_name EntryString_Field extends EntryField

@onready var line_edit: LineEdit = $LineEdit

func _on_line_edit_text_changed(new_text: String) -> void:
  value_changed.emit(new_text)

func set_value(new_value):
  line_edit.text = str(new_value)
