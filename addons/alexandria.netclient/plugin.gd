@tool
extends EditorPlugin

func _enter_tree() -> void:
  # Initialization of the plugin goes here.
  if not EditorInterface.is_plugin_enabled("alexandria.db"):
    var script_path := (get_script() as Script).resource_path
    var plugin_name := script_path.get_slice("/", script_path.get_slice_count("/") - 2)
    OS.alert(plugin_name + " is an extension of the Alexandria Database plugin. Install and enable alexandria.db first, then retry enabling this one.", "Cannot enable extension plugin without core")
    await get_tree().process_frame
    EditorInterface.set_plugin_enabled(plugin_name, false)
    return
  add_autoload_singleton("AlexandriaNetClient", "res://addons/alexandria.netclient/alexandria_net_client.gd")

func _exit_tree() -> void:
  # Clean-up of the plugin goes here.
  remove_autoload_singleton("AlexandriaNetClient")
