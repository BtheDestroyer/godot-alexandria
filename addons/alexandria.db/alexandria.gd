class_name _Alexandria extends Node

class SchemaData:
  var schema_name: String
  var schema_path: String
  var script_path: String
  var resource_script: GDScript
  var exported_properties: PackedStringArray

  static func load(schema_name: String) -> SchemaData:
    var schema_path: String = Alexandria.config.database_root.path_join(schema_name)
    var script_path := schema_path.path_join("schema.gd")
    if not FileAccess.file_exists(script_path):
      push_error("`schema.gd` is missing in: ", schema_path)
      return null
    var resource_script := load(script_path) as GDScript
    if resource_script == null:
      push_error("Failed to load: ", script_path)
      return null
    var schema_data := SchemaData.new()
    schema_data.schema_name = schema_name
    schema_data.schema_path = schema_path
    schema_data.script_path = script_path
    schema_data.resource_script = resource_script
    schema_data.exported_properties = _Alexandria.filter_exported_properties(resource_script.get_script_property_list())
    print("Alexandria loaded data for schema: ", schema_name)
    return schema_data

  func get_entries() -> PackedStringArray:
    return Array(DirAccess.get_files_at(schema_path)).filter(func(file: String): return file.ends_with(".tres") or file.ends_with(".res")).map(func(file: String): return file.get_basename())

  func has_entry(entry_name: String) -> bool:
    return FileAccess.file_exists(schema_path.path_join(entry_name + ".tres")) or FileAccess.file_exists(schema_path.path_join(entry_name + ".res"))

  func create_entry(entry_name: String, binary := false) -> Error:
    if has_entry(entry_name):
      return ERR_ALREADY_EXISTS
    var new_entry := resource_script.new()
    return ResourceSaver.save(new_entry, schema_path.path_join(entry_name + (".res" if binary else ".tres")))

  func get_entry(entry_name: String) -> Resource:
    if FileAccess.file_exists(schema_path.path_join(entry_name + ".tres")):
      return load(schema_path.path_join(entry_name + ".tres")) as Resource
    elif FileAccess.file_exists(schema_path.path_join(entry_name + ".res")):
      return load(schema_path.path_join(entry_name + ".res")) as Resource
    return null

  func update_entry(entry_name: String, entry_data: Resource) -> Error:
    if FileAccess.file_exists(schema_path.path_join(entry_name + ".tres")):
      return ResourceSaver.save(entry_data, schema_path.path_join(entry_name + ".tres"))
    elif FileAccess.file_exists(schema_path.path_join(entry_name + ".res")):
      return ResourceSaver.save(entry_data, schema_path.path_join(entry_name + ".res"))
    return ERR_DOES_NOT_EXIST

  func delete_entry(entry_name: String) -> Error:
    if FileAccess.file_exists(schema_path.path_join(entry_name + ".tres")):
      return DirAccess.remove_absolute(schema_path.path_join(entry_name + ".tres"))
    elif FileAccess.file_exists(schema_path.path_join(entry_name + ".res")):
      return DirAccess.remove_absolute(schema_path.path_join(entry_name + ".res"))
    return ERR_DOES_NOT_EXIST

var config := AlexandriaConfig.new()
var schema_library: Array[SchemaData]

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
  if config.load_default() != OK:
    push_warning("Failed to load config at: " + config.PATH + "\nSaving defaults...")
  if config.save_default() != OK:
    push_error("Failed to save config to: " + config.PATH + "\nPlease ensure you have write permissions.")
  _build_schema_library()

func _build_schema_library() -> void:
  var schema_names := Array(DirAccess.get_directories_at(config.database_root))
  schema_library.assign(schema_names.map(SchemaData.load).filter(func(x): return x != null))

func get_schema_list() -> PackedStringArray:
  return schema_library.map(func(schema_data: SchemaData) -> String: return schema_data.schema_name)

func get_schema_data(schema_name: String) -> SchemaData:
  for schema_data in schema_library:
    if schema_data.schema_name == schema_name:
      return schema_data
  return null
