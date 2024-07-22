extends Node

const SCHEMA_BUTTON_PREFAB := preload("res://schema_button.tscn")
@export var schema_button_container: Control
@export var entry_button_container: Control
@export var new_entry_name: LineEdit
@export var new_entry_button: Button
@export var entry_delete_button: Button
@export var entry_field_container: Control

var selected_schema_data: Alexandria.SchemaData
var selected_entry_name: String
var selected_entry: Resource

func test_db() -> void:
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

func test_remote_db() -> void:
  while not AlexandriaNetClient.connection.is_socket_connected():
    push_warning("AlexandriaNetClient.connection is not connected...")
    await get_tree().create_timer(0.5).timeout
  print("Remote entries: ", await AlexandriaNetClient.get_remote_entries("test"))
  var transaction := Alexandria_TX_Test.new()
  transaction.entry_name = "a"
  match await AlexandriaNetClient.apply_remote_transaction("tx_test", transaction):
    var result when result[0] == OK:
      print("Transaction applied")
    var error_result:
      push_error("Failed to apply transaction: ", error_string(error_result[0]), "; Details: ", error_result[1])

func _ready() -> void:
  if not Alexandria.library_loaded:
    await Alexandria.loaded_schema_library
  for schema_name: String in Alexandria.get_schema_list():
    var schema_button := Button.new()
    schema_button.toggle_mode = true
    schema_button.text = schema_name
    schema_button.pressed.connect(_on_schema_button_pressed.bind(schema_name, schema_button))
    schema_button.pressed.connect(_on_list_button_pressed.bind(schema_button_container, schema_button))
    schema_button_container.add_child(schema_button)
  test_remote_db()

func _notification(what: int) -> void:
  match what:
    NOTIFICATION_EXIT_TREE:
      save_current_entry()

func _on_list_button_pressed(container: Control, button: Button) -> void:
  for child: Button in container.get_children():
    child.button_pressed = child == button

func save_current_entry() -> void:
  if not selected_entry or not selected_schema_data:
    return
  selected_schema_data.update_entry(selected_entry_name, selected_entry)

func clear_entry_button_list() -> void:
  for button: Button in entry_button_container.get_children():
    button.queue_free()

func clear_entry_field_list() -> void:
  for field: EntryField in entry_field_container.get_children():
    field.queue_free()
    entry_field_container.remove_child(field)

func _on_schema_button_pressed(schema_name: String, schema_button: Button) -> void:
  if selected_schema_data and selected_schema_data.schema_name == schema_name:
    return
  save_current_entry()
  clear_entry_button_list()
  clear_entry_field_list()
  new_entry_name.text = ""
  selected_entry_name = ""
  selected_entry = null
  entry_delete_button.disabled = true
  selected_schema_data = Alexandria.get_schema_data(schema_name)
  for entry_name: String in selected_schema_data.get_entries():
    _create_entry_button(entry_name)

func _create_entry_button(entry_name: String) -> void:
  var entry_button := Button.new()
  entry_button.toggle_mode = true
  entry_button.text = entry_name
  entry_button.pressed.connect(_on_entry_button_pressed.bind(entry_name, entry_button))
  entry_button.pressed.connect(_on_list_button_pressed.bind(entry_button_container, entry_button))
  entry_button_container.add_child(entry_button)

func _on_entry_button_pressed(entry_name: String, entry_button: Button) -> void:
  save_current_entry()
  clear_entry_field_list()
  entry_delete_button.disabled = false
  selected_entry_name = entry_name
  selected_entry = selected_schema_data.get_entry(entry_name)
  for property_name: String in _Alexandria.get_exported_properties(selected_entry):
    match selected_entry.get(property_name):
      var var_string when var_string is String or var_string is StringName:
        _create_entry_field(selected_entry, preload("res://entry_field_nodes/entry_field_string.tscn"), property_name, var_string)
      var var_float when var_float is float:
        _create_entry_field(selected_entry, preload("res://entry_field_nodes/entry_field_float.tscn"), property_name, var_float)
      var var_int when var_int is int:
        _create_entry_field(selected_entry, preload("res://entry_field_nodes/entry_field_int.tscn"), property_name, var_int)
      var var_unknown:
        _create_entry_field(selected_entry, preload("res://entry_field_nodes/entry_field_unknown.tscn"), property_name, var_unknown)

func _create_entry_field(entry: Resource, field_prefab: PackedScene, field_name: String, field_value) -> void:
  var new_field: EntryField = field_prefab.instantiate()
  new_field.name = field_name
  entry_field_container.add_child(new_field)
  new_field.set_value(field_value)
  new_field.value_changed.connect(func(new_value): entry.set(field_name, new_value))

func _on_new_entry_button_new_entry_requested(new_entry_name: String) -> void:
  if not selected_schema_data:
    return
  match selected_schema_data.create_entry(new_entry_name):
    OK:
      pass
    var error:
      push_error("Failed to create new entry: ", error_string(error))
      return
  _create_entry_button(new_entry_name)
  var new_entry_button: Button = entry_button_container.get_child(entry_button_container.get_child_count() - 1)
  for i in range(entry_button_container.get_child_count() - 1):
    if entry_button_container.get_child(i).text.naturalnocasecmp_to(new_entry_name) > 0:
      entry_button_container.move_child(new_entry_button, i)
      break
  new_entry_button.button_pressed = true
  new_entry_button.pressed.emit()

func _on_entry_delete_button_pressed() -> void:
  if not selected_schema_data or not selected_entry:
    return
  selected_schema_data.delete_entry(selected_entry_name)
  clear_entry_field_list()
  for button in entry_button_container.get_children():
    if button.text == selected_entry_name:
      button.queue_free()
  selected_entry = null
  selected_entry_name = ""
  entry_delete_button.disabled = true
