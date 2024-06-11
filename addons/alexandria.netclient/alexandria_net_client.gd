class_name _AlexandriaNetClient extends AlexandriaNet

var connection := AlexandriaNet_PacketPeerTCP.new()
var config := AlexandriaNetClientConfig.new()

func is_client() -> bool:
  return true

func _ready() -> void:
  Alexandria.config.save_properties.connect(config.save_properties)
  Alexandria.config.load_properties.connect(config.load_properties)
  await Alexandria.config.loaded
  if not config.enabled:
    return
  match connection.connect_to_host(config.address, config.port):
    OK:
      print("AlexandriaNetClient connected @ ", config.address, ":", config.port)
    var error:
      push_error("AlexandriaNetClient failed to connect @ ", config.address, ":", config.port, "; Error: ", error_string(error))
      return
  got_database_entry.connect(_add_remote_entry)

func _process(_delta: float) -> void:
  connection.poll()
  if not connection.is_socket_connected():
    return
  while connection.get_available_packet_count() > 0:
    var data := AlexandriaNet_PacketDataBuffer.new(connection.get_packet())
    var packet := deserialize_packet(data)
    packet.handle(connection, self)

# Schema Name -> Entry Name
var remote_entries := {}
func _add_remote_entry(schema_name: String, entry_name: String, entry: Resource) -> void:
  if not remote_entries.has(schema_name):
    remote_entries[schema_name] = {}
  remote_entries[schema_name][entry_name] = entry

func get_remote_entry(schema_name: String, entry_name: String, create_if_does_not_exist := false, timeout := 10.0) -> Resource:
  var request_packet := DatabaseReadRequestPacket.new()
  request_packet.schema_name = schema_name
  request_packet.entry_name = entry_name
  request_packet.create_if_does_not_exist = create_if_does_not_exist
  match connection.put_packet(serialize_packet(request_packet).raw_bytes()):
    OK:
      pass
    var error:
      push_error("AlexandriaNetClient failed to send read request packet: ", error_string(error))
      return null
  if remote_entries.get(schema_name, {}).has(entry_name):
    remote_entries[schema_name].erase(entry_name)
  var max_time := Time.get_ticks_msec() + timeout * 1000.0
  while not remote_entries.get(schema_name, {}).has(entry_name):
    if Time.get_ticks_msec() > max_time:
      push_error("AlexandriaNetClient read request for ", schema_name, "/", entry_name, "timed out")
      return null
    await get_tree().create_timer(0.1).timeout
  return remote_entries[schema_name][entry_name]

func update_remote_entry(schema_name: String, entry_name: String, entry: Resource) -> Error:
  var schema_data := Alexandria.get_schema_data(schema_name)
  if not schema_data:
    return ERR_INVALID_PARAMETER
  var request_packet := DatabaseWriteRequestPacket.new()
  request_packet.schema_name = schema_name
  request_packet.entry_name = entry_name
  request_packet.entry_data = schema_data.serialize_entry(entry_name, entry)
  match connection.put_packet(serialize_packet(request_packet).raw_bytes()):
    OK:
      pass
    var error:
      push_error("AlexandriaNetClient failed to send request packet: ", error_string(error))
      return error
  # TODO: Wait for the correct DatabaseWriteResponsePacket and return the Error code
  return OK
