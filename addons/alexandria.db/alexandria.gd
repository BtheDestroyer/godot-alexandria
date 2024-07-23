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

  func serialize_entry(entry_name: String, entry: Resource = null) -> PackedByteArray:
    if entry == null:
      entry = get_entry(entry_name)
      if entry == null:
        push_error("No entry for the Alexandria schema \"", schema_name, "\" with the name: ", entry_name)
        return []
    var data := {
      "db": {
        "schema": schema_name,
        "entry": entry_name,
        "binary": entry.resource_path.ends_with(".res")
      },
      "entry": {}
    }
    for property: String in exported_properties:
      data["entry"][property] = entry.get(property)
    var json := JSON.stringify(data)
    return json.to_utf8_buffer()

  func deserialize_entry(buffer: PackedByteArray) -> Resource:
    if buffer.size() == 0:
      return null
    var json := buffer.get_string_from_utf8()
    var data := JSON.parse_string(json)
    if data["db"]["schema"] != schema_name:
      push_error("Tried to deserialize an Alexandria entry for the schema \"", data["db"]["schema"], "\" with the schema \"", schema_name, "\"")
      return null
    var entry: Resource = resource_script.new()
    entry.resource_path = entries_path.path_join(data["db"]["entry"]) + (".res" if data["db"]["binary"] else ".tres")
    for property: String in exported_properties:
      entry.set(property, data["entry"].get(property, entry.get(property)))
    return entry

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
  exported_properties.assign(properties.filter(func(property: Dictionary): return property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE != 0).map(func(property: Dictionary): return property["name"]))
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
