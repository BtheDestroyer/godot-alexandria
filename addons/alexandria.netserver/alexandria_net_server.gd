class_name _AlexandriaNetServer extends AlexandriaNet

var tcp_server := TCPServer.new()
var connected_clients: Array[AlexandriaNet_PacketPeerTCP]
var config := AlexandriaNetServerConfig.new()

func _ready() -> void:
  Alexandria.config.save_properties.connect(config.save_properties)
  Alexandria.config.load_properties.connect(config.load_properties)
  await Alexandria.config.loaded
  if not config.enabled:
    return
  match tcp_server.listen(config.port, config.bind_address):
    OK:
      print("AlexandriaNetServer hosting @ ", config.bind_address, ":", config.port)
    var error:
      push_error("AlexandriaNetServer failed to host @ ", config.bind_address, ":", config.port, "; Error: ", error_string(error))
      return

func _process(_delta: float) -> void:
  if not tcp_server.is_listening():
    return
  if tcp_server.is_connection_available():
    var client := AlexandriaNet_PacketPeerTCP.new(tcp_server.take_connection())
    connected_clients.push_back(client)
    print("AlexandriaNetServer got a new connection from ", client.get_connected_host(), ":", client.get_connected_port())
  var to_remove: Array[AlexandriaNet_PacketPeerTCP]
  for client: AlexandriaNet_PacketPeerTCP in connected_clients:
    if client.poll() != OK or client.is_socket_disconnected():
      print("AlexandriaNetServer dropped the connection from ", client.get_connected_host(), ":", client.get_connected_port())
      client.disconnect_from_host()
      to_remove.push_back(client)
      continue
    while client.get_available_packet_count() > 0:
      var data := AlexandriaNet_PacketDataBuffer.new(client.get_packet())
      var packet := deserialize_packet(data)
      packet.handle(client, self)
  for client in to_remove:
    connected_clients.erase(client)
