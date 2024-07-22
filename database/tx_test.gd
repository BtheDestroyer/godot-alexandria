class_name Alexandria_TX_Test extends Alexandria_Transaction

@export var entry_name: String

# Returns `true` if the transaction requirements are satisfied, `false` otherwise
func check_requirements() -> bool:
  var entry := Alexandria.get_entry(&"test", entry_name)
  if entry == null:
    return false
  if entry.bar < 3:
    return false
  return true

# Applies the transaction. This *must not fail*; any conditional checks must be done in `check_requirements`
func apply() -> void:
  var schema := Alexandria.get_schema_data(&"test")
  var entry := schema.get_entry(entry_name)
  entry.bar -= 3
  entry.foo = "[Golden] " + entry.foo
  schema.update_entry(entry_name, entry)
