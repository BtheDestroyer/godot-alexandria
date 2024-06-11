@tool
class_name AlexandriaEditorPlugin extends EditorPlugin

func _enter_tree() -> void:
  # Initialization of the plugin goes here.
  add_autoload_singleton("Alexandria", "res://addons/alexandria.db/alexandria.tscn")

func _exit_tree() -> void:
  # Clean-up of the plugin goes here.
  remove_autoload_singleton("Alexandria")
  var extensions := Array(DirAccess.get_directories_at("res://addons/")).filter(func(x): return x.begins_with("alexandria.") and x != "alexandria.db")
  for extension in extensions:
    get_tree().process_frame.connect(func(): if EditorInterface.is_plugin_enabled(extension): EditorInterface.set_plugin_enabled(extension, false), CONNECT_ONE_SHOT)
