class_name AlexandriaConfig extends ConfigFile

const PATH := "./alexandria.cfg"
@export var database_root := "./database/"

func save(path: String) -> Error:
  save_properties.emit(self)
  for property in _Alexandria.get_exported_properties(self):
    set_value("Alexandria", property, get(property))
  return super(path)

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
  return OK

func load_default() -> Error:
  return self.load(PATH)

signal save_properties(config: AlexandriaConfig)
signal load_properties(config: AlexandriaConfig)
