class_name EntryField_Unknown extends EntryField

@onready var value_label: Label = $ValueLabel

func set_value(new_value):
  value_label.text = str(new_value)
