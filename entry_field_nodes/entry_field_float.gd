class_name EntryField_Float extends EntryField

@onready var spin_box: SpinBox = $SpinBox

func _on_spin_box_value_changed(value: float) -> void:
  value_changed.emit(value)

func _notification(what: int) -> void:
  match what:
    NOTIFICATION_EXIT_TREE:
      value_changed.emit(spin_box.value)

func set_value(new_value):
  spin_box.value = new_value
