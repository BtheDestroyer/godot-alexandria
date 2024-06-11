class_name AlexandriaNetServerConfig

## Enables the AlexandriaNetServer which allows remote AlexandriaNetClients to connect
@export var enabled := true
## Local address on which to host
@export var bind_address := "*"
## Local port on which to host
@export var port := AlexandriaNet.DEFAULT_PORT

func save_properties(config: AlexandriaConfig) -> void:
  for property in _Alexandria.get_exported_properties(self):
    config.set_value("AlexandriaNetServer", property, get(property))

func load_properties(config: AlexandriaConfig) -> void:
  for property in _Alexandria.get_exported_properties(self):
    if config.has_section_key("AlexandriaNetServer", property):
      set(property, config.get_value("AlexandriaNetServer", property))
