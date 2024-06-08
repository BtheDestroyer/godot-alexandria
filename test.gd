extends Node

func _ready() -> void:
  var schema_data := Alexandria.get_schema_data("test")
  match schema_data.create_entry("foo"):
    OK:
      pass
    var error:
      push_error("Failed to create entry: ", error_string(error))
      return
  var entry := schema_data.get_entry("foo") as AlexandriaSchema_Test
  if entry == null:
    push_error("Failed to get entry data")
    return
  entry.foo = "bar"
  entry.bar = 42
  match schema_data.update_entry("foo", entry):
    OK:
      pass
    var error:
      push_error("Failed to update entry: ", error_string(error))
      return
  match schema_data.delete_entry("foo"):
    OK:
      pass
    var error:
      push_error("Failed to delete entry: ", error_string(error))
      return
