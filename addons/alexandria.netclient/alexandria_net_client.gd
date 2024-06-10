class_name _AlexandriaNetClient extends AlexandriaNet

var connection := AlexandriaNet_PacketPeerTCP.new()
var config := AlexandriaNetClientConfig.new()

func _ready() -> void:
  Alexandria.config.save_properties.connect(config.save_properties)
  Alexandria.config.load_properties.connect(config.load_properties)
  await Alexandria.ready
  if not config.enabled:
    return
  match connection.connect_to_host(config.address, config.port):
    OK:
      print("AlexandriaNetClient connected @ ", config.address, ":", config.port)
    var error:
      push_error("AlexandriaNetClient failed to connect @ ", config.address, ":", config.port, "; Error: ", error_string(error))
      return

func _process(_delta: float) -> void:
  connection.poll()
  if not connection.is_socket_connected():
    return
  while connection.get_available_packet_count() > 0:
    var data := AlexandriaNet_PacketDataBuffer.new(connection.get_packet())
    var packet := deserialize_packet(data)
    packet.handle(connection, self)
