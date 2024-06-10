class_name AlexandriaNet_PacketPeerTCP extends PacketPeerStream

func _init(stream_peer := StreamPeerTCP.new()) -> void:
  self.stream_peer = stream_peer

func bind(address: String, port: int) -> Error:
  return stream_peer.bind(address, port)

func connect_to_host(address: String, port: int) -> Error:
  match stream_peer.connect_to_host(address, port):
    OK:
      pass
    var error:
      return error
  return OK

func disconnect_from_host() -> void:
  stream_peer.disconnect_from_host()

func get_connected_host() -> String:
  return stream_peer.get_connected_host()

func get_connected_port() -> int:
  return stream_peer.get_connected_port()

func get_local_port() -> int:
  return stream_peer.get_local_port()

func get_status() -> StreamPeerTCP.Status:
  return stream_peer.get_status()

func poll() -> Error:
  return stream_peer.poll()

func set_no_delay(enabled: bool) -> void:
  stream_peer.set_no_delay(enabled)

func is_socket_connected() -> bool:
  match get_status():
    StreamPeerTCP.Status.STATUS_CONNECTED:
      return true
  return false

func is_socket_disconnected() -> bool:
  match get_status():
    StreamPeerTCP.Status.STATUS_ERROR, StreamPeerTCP.Status.STATUS_NONE:
      return true
  return false
