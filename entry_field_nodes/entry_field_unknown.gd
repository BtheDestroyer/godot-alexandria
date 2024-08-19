class_name EntryField_Unknown extends EntryField

@onready var value_label: Label = $ValueLabel

static func _encode_array(array: Array) -> String:
  return "[\n    %s\n]" % [",\n    ".join(array.map(_encode_value))]

static func _encode_kvp(key_value_pair: Array) -> String:
  return "%s:%s" % key_value_pair.map(_encode_value)

static func _encode_dictionary(dict: Dictionary) -> String:
  return "{\n    %s\n}" % [",\n    ".join(dict.keys().map(func(key) -> String: return _encode_kvp([key, dict[key]])))]

static func _encode_value(value) -> String:
  if value is Resource:
    if Alexandria.is_resource_an_entry(value):
      return "Entry{%s/%s}" % [value.resource_path.get_base_dir().get_file(), value.resource_path.get_file().get_basename()]
    return "Resource{%s}" % [value.resource_path]
  if value is Array:
    return _encode_array(value)
  if value is String:
    return "\"%s\"" % [value]
  if value is Dictionary:
    return _encode_dictionary(value)
  return str(value)

func set_value(new_value) -> void:
  value_label.text = _encode_value(new_value)
