class_name _Alexandria extends Node

# UUID implementation inspired by: https://github.com/binogure-studio/godot-uuid/
static func _uuid_base() -> PackedByteArray:
  # Avoids for loop, magic number bitmask
  var bytes: PackedByteArray
  bytes.resize(16)
  bytes.encode_u32(0, randi())
  bytes.encode_u32(4, (randi() & 0xFF0FFF3F) | 0x00400080)
  bytes.encode_u32(8, randi())
  bytes.encode_u32(12, randi())
  return bytes

static func uuid_v4() -> String:
  return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % Array(_uuid_base())

class SchemaData:
  var schema_name: String
  var entries_path: String
  var script_path: String
  var resource_script: GDScript
  var exported_properties: PackedStringArray
  var deserialized_entries: Dictionary # Entry Name (String) -> Entry (WeakRef)

  static func find_valid_script_path(schema_name: String) -> String:
    var directories_to_check := PackedStringArray()
    if Alexandria.config.schema_root.begins_with("./"):
      directories_to_check.push_back("res://".path_join(Alexandria.config.schema_root.substr(2)))
    directories_to_check.push_back(Alexandria.config.schema_root)
    for directory in directories_to_check:
      var schema_path := directory.path_join(schema_name)
      for script_path in [schema_path.path_join("schema.gd"), schema_path + ".gd"]:
        if FileAccess.file_exists(script_path):
          return script_path
    return ""

  static func load(schema_name: String) -> SchemaData:
    var script_path := find_valid_script_path(schema_name)
    if script_path.is_empty():
      push_error("No script file for Alexandria schema: ", schema_name)
      return null
    var resource_script := load(script_path) as GDScript
    if resource_script == null:
      push_error("Failed to load Alexandria schema script: ", script_path)
      return null
    if resource_script.new() is Alexandria_Transaction:
      # Silently ignore transactions
      return null
    var schema_data := SchemaData.new()
    schema_data.schema_name = schema_name
    schema_data.entries_path = Alexandria.config.database_root.path_join(schema_name)
    if not DirAccess.dir_exists_absolute(schema_data.entries_path):
      DirAccess.make_dir_recursive_absolute(schema_data.entries_path)
    schema_data.script_path = script_path
    schema_data.resource_script = resource_script
    schema_data.exported_properties = _Alexandria.filter_exported_properties(resource_script.get_script_property_list())
    print("Alexandria loaded data for schema: ", schema_name)
    return schema_data

  func get_entries() -> PackedStringArray:
    if not Alexandria.config.enable_local_database:
      return []
    return Array(DirAccess.get_files_at(entries_path)).filter(func(file: String): return file.ends_with(".tres") or file.ends_with(".res")).map(func(file: String): return file.get_basename())

  func has_entry(entry_name: String) -> bool:
    if not Alexandria.config.enable_local_database:
      return false
    return FileAccess.file_exists(entries_path.path_join(entry_name + ".tres")) or FileAccess.file_exists(entries_path.path_join(entry_name + ".res"))

  func create_entry(entry_name: String, owner: Alexandria_User = null, binary: bool = Alexandria.config.entries_default_as_binary) -> Error:
    if not Alexandria.config.enable_local_database:
      return ERR_DATABASE_CANT_WRITE
    if has_entry(entry_name):
      return ERR_ALREADY_EXISTS
    var new_entry := resource_script.new()
    if new_entry is Alexandria_Entry:
      new_entry.owner = owner
    return ResourceSaver.save(new_entry, entries_path.path_join(entry_name + (".res" if binary else ".tres")))

  func get_entry(entry_name: String) -> Resource:
    if not Alexandria.config.enable_local_database:
      return null
    if FileAccess.file_exists(entries_path.path_join(entry_name + ".tres")):
      return load(entries_path.path_join(entry_name + ".tres")) as Resource
    elif FileAccess.file_exists(entries_path.path_join(entry_name + ".res")):
      return load(entries_path.path_join(entry_name + ".res")) as Resource
    return null

  func update_entry(entry_name: String, entry_data: Resource) -> Error:
    if not Alexandria.config.enable_local_database:
      return ERR_DATABASE_CANT_WRITE
    if FileAccess.file_exists(entries_path.path_join(entry_name + ".tres")):
      return ResourceSaver.save(entry_data, entries_path.path_join(entry_name + ".tres"))
    elif FileAccess.file_exists(entries_path.path_join(entry_name + ".res")):
      return ResourceSaver.save(entry_data, entries_path.path_join(entry_name + ".res"))
    return ERR_DOES_NOT_EXIST

  func delete_entry(entry_name: String) -> Error:
    if not Alexandria.config.enable_local_database:
      return ERR_DATABASE_CANT_WRITE
    if FileAccess.file_exists(entries_path.path_join(entry_name + ".tres")):
      return DirAccess.remove_absolute(entries_path.path_join(entry_name + ".tres"))
    elif FileAccess.file_exists(entries_path.path_join(entry_name + ".res")):
      return DirAccess.remove_absolute(entries_path.path_join(entry_name + ".res"))
    return ERR_DOES_NOT_EXIST

  func _encode_property(property: String, value, encoded_properties: Array[String], entry_name: String, fully_encode_child_entries: bool):
    if value is Array:
      var encoded := []
      for i in range(value.size()):
        encoded.push_back(_encode_property("%s:%d" % [property, i], value[i], encoded_properties, entry_name, fully_encode_child_entries))
      return encoded
    if value is Dictionary:
      var encoded := {}
      for key in value:
        encoded[key] = _encode_property("%s:%s" % [property, str(key)], value[key], encoded_properties, entry_name, fully_encode_child_entries)
      return encoded
    if value is not Resource:
      return value
    if Alexandria.is_resource_an_entry(value):
      var child_schema_name: String = value.resource_path.get_base_dir().get_file()
      var child_schema: SchemaData = Alexandria.get_schema_data(child_schema_name)
      encoded_properties.push_back(property)
      var child_entry_name: String = value.resource_path.get_file().get_basename()
      if fully_encode_child_entries:
        return child_schema.convert_entry_to_dictionary(child_entry_name, value)
      return {
        "db": {
          "schema": child_schema_name,
          "entry": child_entry_name,
          "binary": value.resource_path.ends_with(".res"),
          "encoded_properties": []
        },
        "entry": null
      }
    if value.resource_path.begins_with("res://"):
      encoded_properties.push_back(property)
      return {
        "script": value.get_script().resource_path,
        "path": value.resource_path
      }
    push_error("Cannot encode local non-entry Resource \"", value.resource_path, "\" (\"", property,"\"),  within database entry: ", schema_name, "/", entry_name)
    return null

  func convert_entry_to_dictionary(entry_name: String, entry: Resource = null, fully_encode_child_entries := false) -> Dictionary:
    if entry == null:
      entry = get_entry(entry_name)
      if entry == null:
        push_error("No entry for the Alexandria schema \"", schema_name, "\" with the name: ", entry_name)
        return {}
    var data := {}
    var encoded_properties: Array[String] = []
    for property: String in exported_properties:
      data[property] = _encode_property(property, entry.get(property), encoded_properties, entry_name, fully_encode_child_entries)
    return {
      "db": {
        "schema": schema_name,
        "entry": entry_name,
        "binary": entry.resource_path.ends_with(".res"),
        "encoded_properties": encoded_properties
      },
      "entry": data
    }

  func _decode_property(property_name: String, encoded_property, encoded_properties: Array[String], entry_name: String):
    if not encoded_properties.has(property_name):
      if encoded_property is Array:
        # Normal Array; may have encoded children
        var decoded := []
        for i in range(encoded_property.size()):
          var full_property_path := "%s:%d" % [property_name, i]
          decoded.push_back(_decode_property(full_property_path, encoded_property[i], encoded_properties, entry_name))
        return decoded
      if encoded_property is Dictionary:
        # Normal Dictionary; may have encoded children
        var decoded := {}
        for key in encoded_property:
          var full_property_path := "%s:%s" % [property_name, str(key)]
          decoded[key] = _decode_property(full_property_path, encoded_property[key], encoded_properties, entry_name)
        return decoded
      return encoded_property
    if encoded_property is Dictionary:
      if encoded_property.size() == 2 and "db" in encoded_property and "entry" in encoded_property:
        # Encoded entry
        var child_schema: SchemaData = Alexandria.get_schema_data(encoded_property["db"]["schema"])
        if child_schema == null:
          push_error("Failed to get local schema \"", encoded_property["db"]["schema"], "\n for an encoded database entry (\"", property_name, "\") as part of database entry: ", schema_name, "/", entry_name)
          return null
        var child_entry := child_schema.convert_dictionary_to_entry(encoded_property)
        if child_entry == null:
          push_error("Failed to convert encoded database entry (\"", property_name, "\") as part of database entry: ", schema_name, "/", entry_name)
        return child_entry
      if encoded_property.size() == 2 and "script" in encoded_property and "path" in encoded_property:
        # Encoded local resource
        var local_resource := ResourceLoader.load(encoded_property["path"])
        if local_resource == null:
          push_error("Failed to load local resource (\"", property_name, "\") as part of database entry: ", schema_name, "/", entry_name)
        return local_resource
    push_error("Failed to decode an encoded property (\"", property_name, "\") as part of database entry: ", schema_name, "/", entry_name)
    return null

  func serialize_entry(entry_name: String, entry: Resource = null, fully_encode_child_entries := false) -> PackedByteArray:
    if entry == null:
      entry = get_entry(entry_name)
      if entry == null:
        push_error("No entry for the Alexandria schema \"", schema_name, "\" with the name: ", entry_name)
        return []
    var data := convert_entry_to_dictionary(entry_name, entry, fully_encode_child_entries)
    var json := JSON.stringify(data)
    print("Serialized data: ", JSON.stringify(data, "  "))
    return json.to_utf8_buffer()

  func convert_dictionary_to_entry(data: Dictionary) -> Resource:
    const EXPECTED_KEYS: PackedStringArray = [
      "db",
      "db:schema",
      "db:entry",
      "db:binary",
      "db:encoded_properties",
      "entry"
    ]
    for key: String in EXPECTED_KEYS:
      var checked_data := data
      for key_portion: String in key.split(":"):
        if key_portion not in checked_data:
          push_error("Tried to deserialize an Dictionary which was not a valid Alexandria entry, missing key: ", key, "\nThis may be due to a plugin version mismatch.")
          return null
        if checked_data[key_portion] is Dictionary:
          checked_data = checked_data[key_portion]
        else:
          checked_data = {}
    if data["db"]["schema"] != schema_name:
      push_error("Tried to deserialize an Alexandria entry for the schema \"", data["db"]["schema"], "\" with the schema \"", schema_name, "\"")
      return null
    var entry_name: String = data["db"]["entry"]
    var entry: Resource = null
    if entry_name in deserialized_entries:
      if is_instance_valid(deserialized_entries[entry_name]):
        entry = deserialized_entries[entry_name].get_ref()
      if entry == null:
        deserialized_entries.erase(entry_name)
    if entry == null and has_entry(entry_name):
      entry = get_entry(entry_name)
    if data["entry"] == null:
      if is_instance_valid(entry):
        return entry
      push_error("Failed to load local entry file (\"", schema_name, "/", entry_name, "\") specified by serialized Alexandria entry data")
      return null
    if entry == null:
      entry = resource_script.new()
      entry.resource_path = entries_path.path_join(data["db"]["entry"]) + (".res" if data["db"]["binary"] else ".tres")
    var encoded_properties: Array[String]
    encoded_properties.assign(data["db"]["encoded_properties"])
    for property: String in Array(exported_properties).filter(data["entry"].keys().has):
      var value = _decode_property(property, data["entry"][property], encoded_properties, entry_name)
      print(property, " = ", value)
      if entry.get(property) is Array:
        entry[property].assign(value) # Avoids issues with typed arrays
      else:
        entry.set(property, value)
    deserialized_entries[entry_name] = weakref(entry)
    return entry

  func deserialize_entry(buffer: PackedByteArray) -> Resource:
    if buffer.size() == 0:
      return null
    var json := buffer.get_string_from_utf8()
    var data := JSON.parse_string(json)
    return convert_dictionary_to_entry(data)

class TransactionData:
  var transaction_name: String
  var script_path: String
  var resource_script: GDScript
  var exported_properties: PackedStringArray

  static func find_valid_script_path(transaction_name: String) -> String:
    var transaction_path: String = Alexandria.config.transactions_root.path_join(transaction_name + ".gd")
    if FileAccess.file_exists(transaction_path):
      return transaction_path
    return ""

  static func load(transaction_name: String) -> TransactionData:
    var script_path := find_valid_script_path(transaction_name)
    if script_path.is_empty():
      push_error("No script file for Alexandria transaction: ", transaction_name)
      return null
    var resource_script := load(script_path) as GDScript
    if resource_script == null:
      push_error("Failed to load Alexandria transaction script: ", script_path)
      return null
    var resource_instance := resource_script.new()
    if not resource_instance is Alexandria_Transaction:
      # Silently ignore non-transactions
      return null
    for required_method: String in ["check_requirements", "apply"]:
      if not resource_instance.has_method(required_method):
        push_error("Alexandria transaction script is missing the ", required_method, " method: ", script_path)
        return null
    var transaction_data := TransactionData.new()
    transaction_data.transaction_name = transaction_name
    transaction_data.script_path = script_path
    transaction_data.resource_script = resource_script
    transaction_data.exported_properties = _Alexandria.filter_exported_properties(resource_script.get_script_property_list())
    print("Alexandria loaded data for transaction: ", transaction_name)
    return transaction_data

  func serialize_transaction(transaction: Alexandria_Transaction = null) -> PackedByteArray:
    if transaction == null:
      push_error("No transaction given for call to Alexandria.TransactionData.serialize_transaction")
      return []
    if transaction.get_script() != resource_script:
      push_error("Transaction type given to Alexandria.TransactionData.serialize_transaction (", (transaction.get_script() as GDScript).resource_path.get_file(), ") was for the wrong transaction resource (", transaction_name, ")")
      return []
    var data := {
      "db": {
        "transaction": transaction_name
      },
      "transaction": {}
    }
    for property: String in exported_properties:
      data["transaction"][property] = transaction.get(property)
    var json := JSON.stringify(data)
    return json.to_utf8_buffer()

  func deserialize_transaction(buffer: PackedByteArray) -> Resource:
    var json := buffer.get_string_from_utf8()
    var data := JSON.parse_string(json)
    if data["db"]["transaction"] != transaction_name:
      push_error("Tried to deserialize an Alexandria transaction for the type \"", data["db"]["transaction"], "\" with the transaction \"", transaction_name, "\"")
      return null
    var transaction: Resource = resource_script.new()
    for property: String in exported_properties:
      transaction.set(property, data["transaction"].get(property, transaction.get(property)))
    return transaction

var config := AlexandriaConfig.new()
var schema_library: Array[SchemaData]
var transaction_library: Array[TransactionData]
var library_loaded := false

static func filter_exported_properties(properties: Array[Dictionary]) -> PackedStringArray:
  var exported_properties: Array[String]
  exported_properties.assign(properties.filter(func(property: Dictionary): return property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE != 0 and property["name"] not in [&"owner", &"owner_permissions", &"everyone_permissions"]).map(func(property: Dictionary): return property["name"]))
  return exported_properties

static func get_exported_properties(object: Object) -> PackedStringArray:
  var script := object.get_script() as Script
  if script == null:
    return []
  return filter_exported_properties(script.get_script_property_list())

func _ready() -> void:
  await get_tree().process_frame # Gives extensions time to connect signals
  if config.load_default() != OK:
    push_warning("Failed to load config at: " + config.PATH + "\nSaving defaults...")
  if config.save_default() != OK:
    push_error("Failed to save config to: " + config.PATH + "\nPlease ensure you have write permissions.")
  if not config.schema_root.begins_with("res://"):
    DirAccess.make_dir_recursive_absolute(config.schema_root)
  if not config.database_root.begins_with("res://"):
    DirAccess.make_dir_recursive_absolute(config.database_root)
  _build_schema_library()
  print("Alexandria loaded ", schema_library.size(), " schemas.")
  _build_transaction_library()
  print("Alexandria loaded ", transaction_library.size(), " transactions.")
  library_loaded = true
  loaded_schema_library.emit()

func _build_schema_library() -> void:
  var schema_names: Array[String]
  schema_names.assign(DirAccess.get_directories_at(config.schema_root))
  schema_library.assign(schema_names.map(SchemaData.load).filter(func(x): return x != null))

func get_schema_list() -> PackedStringArray:
  return schema_library.map(func(schema_data: SchemaData) -> String: return schema_data.schema_name)

func does_schema_exist(schema_name: String) -> bool:
  return schema_name in schema_library

func get_schema_data(schema_name: String) -> SchemaData:
  for schema_data in schema_library:
    if schema_data.schema_name == schema_name:
      return schema_data
  return null

func _build_transaction_library() -> void:
  var transaction_names: Array[String]
  transaction_names.assign(DirAccess.get_files_at(config.transactions_root))
  transaction_library.assign(transaction_names.map(func(x:String): return TransactionData.load(x.get_basename())).filter(func(x): return x != null))

func get_transaction_list() -> PackedStringArray:
  return transaction_library.map(func(schema_data: SchemaData) -> String: return schema_data.schema_name)

func get_transaction_data(transaction_name: String) -> TransactionData:
  for transaction_data in transaction_library:
    if transaction_data.transaction_name == transaction_name:
      return transaction_data
  return null

func is_resource_path_an_entry(resource_path: String) -> bool:
  if ProjectSettings.globalize_path(resource_path.get_base_dir().get_base_dir()) != ProjectSettings.globalize_path(config.database_root):
    return false
  var schema_name := resource_path.get_base_dir().get_file()
  if not does_schema_exist(schema_name):
    return false
  return is_resource_an_entry(ResourceLoader.load(resource_path))

func is_resource_an_entry(resource: Resource) -> bool:
  var schema_name := resource.resource_path.get_base_dir().get_file()
  var schema_data := get_schema_data(schema_name)
  if not schema_data:
    return false
  return resource.get_script() == schema_data.resource_script

func get_entry(schema_name: String, entry_name: String) -> Resource:
  var schema_data := get_schema_data(schema_name)
  if not schema_data:
    return null
  return schema_data.get_entry(entry_name)

func get_entry_permissions_for_user(entry: Resource, user: Alexandria_User) -> Alexandria_Entry.Permissions:
  var permissions := Alexandria_Entry.Permissions.NONE
  if entry is Alexandria_Entry:
    if entry.owner == user:
      permissions |= entry.owner_permissions
    else:
      permissions |= entry.everyone_permissions
  else:
    permissions |= Alexandria_Entry.Permissions.READ_UPDATE
  match user.rank:
    Alexandria_User.Rank.UNVALIDATED:
      permissions &= Alexandria_Entry.Permissions.READ
    Alexandria_User.Rank.USER:
      pass
    Alexandria_User.Rank.MODERATOR:
      permissions |= Alexandria_Entry.Permissions.READ
    Alexandria_User.Rank.ADMINISTRATOR:
      permissions |= Alexandria_Entry.Permissions.READ_UPDATE
    Alexandria_User.Rank.DEVELOPER:
      permissions |= Alexandria_Entry.Permissions.READ_UPDATE_DELETE
  return permissions

signal loaded_schema_library
