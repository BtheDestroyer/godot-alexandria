class_name AlexandriaConfig extends ConfigFile

const PATH := "./alexandria.cfg"
## Enables entry interfaces of Alexandria.SchemaData
## Should be disabled for projects which only use remote databases
@export var enable_local_database := true
## Root folder of database entries
## Schema entries are located in: <database_root>/<schema_name>/
@export var database_root := "./database/"
## Root folder of schema scripts
## Schema scripts can be named:
## - <schema_root>/<schema_name>/schema.gd
## - <schema_root>/<schema_name>.gd
@export var schema_root := "./database/"
## Root folder of transaction scripts
## Transaction scripts can be named:
## - <transactions_root>/<transaction_name>.gd
@export var transactions_root := "./database/"
## If true, new entries will be created as binary .res files
## Otherwise, new entries will be created as text .tres files
@export var entries_default_as_binary := true

func save(path: String) -> Error:
  save_properties.emit(self)
  for property in _Alexandria.get_exported_properties(self):
    set_value("Alexandria", property, get(property))
  var super_result := super(path)
  if super_result == OK:
    saved.emit()
  return super_result

func save_default() -> Error:
  return self.save(PATH)

func load(path: String = PATH) -> Error:
  match super(path):
    OK:
      pass
    var error:
      return error
  load_properties.emit(self)
  for property in _Alexandria.get_exported_properties(self):
    if has_section_key("Alexandria", property):
      set(property, get_value("Alexandria", property))
  loaded.emit()
  return OK

func load_default() -> Error:
  if PATH.begins_with("./"):
    var builtin_path := "res://".path_join(PATH.substr(2))
    if FileAccess.file_exists(builtin_path):
      match self.load(builtin_path):
        OK:
          pass
        var error:
          push_error("Alexandria failed to load built-in config")
          return error
    if FileAccess.file_exists(PATH):
      var extern_config := ConfigFile.new()
      match extern_config.load(PATH):
        OK:
          pass
        var error:
          push_error("Alexandria failed to load local config")
          return error
      merge(extern_config)
  return self.load(PATH)

func merge(other: ConfigFile):
  for property in _Alexandria.get_exported_properties(self):
    if has_section_key("Alexandria", property):
      set(property, other.get_value("Alexandria", property))

signal save_properties(config: AlexandriaConfig)
signal load_properties(config: AlexandriaConfig)
signal saved
signal loaded
