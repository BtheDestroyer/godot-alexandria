extends Button

@export var line_edit: LineEdit
@export var entry_container: Control

func _on_new_entry_name_text_changed(new_text: String) -> void:
  disabled = true
  if new_text == "":
    return
  for child: Button in entry_container.get_children():
    if child.text == new_text:
      return
  disabled = false

func _on_new_entry_name_text_submitted(_new_text: String) -> void:
  if not disabled:
    _pressed()

func _pressed() -> void:
  new_entry_requested.emit(line_edit.text)
  line_edit.text = ""
  disabled = true

signal new_entry_requested(new_entry_name: String)
