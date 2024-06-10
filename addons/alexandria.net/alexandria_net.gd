class_name AlexandriaNet extends Node

class Packet:
  static func get_name() -> StringName:
    return &"Packet"

  func serialize() -> AlexandriaNet_PacketDataBuffer:
    return AlexandriaNet_PacketDataBuffer.new()

  func deserialize(data: AlexandriaNet_PacketDataBuffer) -> void:
    pass

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    return ERR_METHOD_NOT_FOUND

class GreetingPacket extends Packet:
  static func get_name() -> StringName:
    return &"GreetingPacket"

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    print(sender.get_connected_host(), ":", sender.get_connected_port(), " -> Greeted!")
    return OK

var packet_types := [
  GreetingPacket
]

func serialize_packet(packet: Packet) -> AlexandriaNet_PacketDataBuffer:
  var data := AlexandriaNet_PacketDataBuffer.new()
  var id := packet_types.find(packet.get_script())
  if id == -1:
    push_error("AlexandriaNet failed to get packet id for packet: ", packet.get_name())
    return data
  data.write_u16(id)
  data.write_packet_data_buffer(packet.serialize())
  return data

func deserialize_packet(data: AlexandriaNet_PacketDataBuffer) -> Packet:
  var id := data.read_u16()
  var packet: Packet = packet_types[id].new()
  packet.deserialize(data.read_packet_data_buffer())
  return packet
