class_name _AlexandriaNetServer extends AlexandriaNet

class ConnectedClient:
  var connection: AlexandriaNet_PacketPeerTCP
  var session_token: AlexandriaNet_SessionToken

  func _init(connection: AlexandriaNet_PacketPeerTCP) -> void:
    self.connection = connection

var tcp_server := TCPServer.new()
var connected_clients: Array[ConnectedClient]
var config := AlexandriaNetServerConfig.new()
var crypto := Crypto.new()
var crypto_key := CryptoKey.new()

func assign_session_token_to_connection(connection: AlexandriaNet_PacketPeerTCP, session_token: AlexandriaNet_SessionToken) -> void:
  for client: ConnectedClient in connected_clients:
    if client.connection == connection:
      client.session_token = session_token
      return

func _generate_crypto_key() -> void:
  crypto_key = crypto.generate_rsa(1024)
  match crypto_key.save("./crypto.key"):
    OK:
      pass
    var error:
      push_error("AlexandriaNetServer failed to save crypto_key: ", error_string(error))

func create_user(username: String) -> Error:
  if user_exists(username):
    return ERR_ALREADY_EXISTS
  var new_user := Alexandria_User.new()
  new_user.username = username
  return OK

func attempt_login(username: String, password: String) -> AlexandriaNet_SessionToken:
  if not user_exists(username):
    return null
  var user := get_user(username)
  if not user.check_password(password):
    return null
  var new_session_token := AlexandriaNet_SessionToken.new(user)
  user.valid_sessions.append(new_session_token)
  return new_session_token

func get_user(username: String) -> Alexandria_User:
  for path: String in [config.users_root.path_join(username + ".res"), config.users_root.path_join(username + ".tres")]:
    if FileAccess.file_exists(path):
      return load(path) as Alexandria_User
  return null

func user_exists(username: String) -> bool:
  return false

func is_server() -> bool:
  return true

func _ready() -> void:
  if FileAccess.file_exists("./crypto.key"):
    if crypto_key.load("./crypto.key") != OK:
      _generate_crypto_key()
  else:
      _generate_crypto_key()
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
    var connection := AlexandriaNet_PacketPeerTCP.new(tcp_server.take_connection())
    connected_clients.push_back(ConnectedClient.new(connection))
    print("AlexandriaNetServer got a new connection from ", connection.get_connected_host(), ":", connection.get_connected_port())
  var to_remove: Array[AlexandriaNet_PacketPeerTCP]
  for client: ConnectedClient in connected_clients:
    if client.connection.poll() != OK or client.connection.is_socket_disconnected():
      print("AlexandriaNetServer dropped the connection from ", client.connection.get_connected_host(), ":", client.connection.get_connected_port())
      client.connection.disconnect_from_host()
      to_remove.push_back(client)
      continue
    while client.connection.get_available_packet_count() > 0:
      var data := AlexandriaNet_PacketDataBuffer.new(client.connection.get_packet())
      var packet := deserialize_packet(data)
      match packet.handle(client.connection, self):
        OK:
          pass
        var error:
          push_error("AlexandriaNetServer failed to handle packet. Error: ", error_string(error), " Packet ID: ", packet_types.find(packet.get_script()))
  for client in to_remove:
    connected_clients.erase(client)
