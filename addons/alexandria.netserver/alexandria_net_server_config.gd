class_name AlexandriaNetServerConfig

@export var bind_address := "*"
@export var port := 34902
@export var enabled := false

func save_properties(config: AlexandriaConfig) -> void:
  for property in _Alexandria.get_exported_properties(self):
    config.set_value("AlexandriaNetServer", property, get(property))

func load_properties(config: AlexandriaConfig) -> void:
  for property in _Alexandria.get_exported_properties(self):
    if config.has_section_key("AlexandriaNetServer", property):
      set(property, config.get_value("AlexandriaNetServer", property))
