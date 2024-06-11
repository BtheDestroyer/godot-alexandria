class_name AlexandriaNetClientConfig

## Enables the connection to the remote AlexandriaNetServer
@export var enabled := true
## Address of the remote AlexandriaNetServer
@export var address := "127.0.0.1"
## Port of the remote AlexandriaNetServer
@export var port := AlexandriaNet.DEFAULT_PORT

func save_properties(config: AlexandriaConfig) -> void:
  for property in _Alexandria.get_exported_properties(self):
    config.set_value("AlexandriaNetClient", property, get(property))

func load_properties(config: AlexandriaConfig) -> void:
  for property in _Alexandria.get_exported_properties(self):
    if config.has_section_key("AlexandriaNetClient", property):
      set(property, config.get_value("AlexandriaNetClient", property))
