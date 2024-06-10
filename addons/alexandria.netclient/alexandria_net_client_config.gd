class_name AlexandriaNetClientConfig

@export var address := "*"
@export var port := 34902
@export var enabled := false

func save_properties(config: AlexandriaConfig) -> void:
  for property in _Alexandria.get_exported_properties(self):
    config.set_value("AlexandriaNetClient", property, get(property))

func load_properties(config: AlexandriaConfig) -> void:
  for property in _Alexandria.get_exported_properties(self):
    if config.has_section_key("AlexandriaNetClient", property):
      set(property, config.get_value("AlexandriaNetClient", property))
