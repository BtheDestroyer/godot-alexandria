class_name AlexandriaNet extends Node

const DEFAULT_PORT := 34902

class Packet:
  static func get_name() -> StringName:
    return &"Packet"

  func serialize() -> AlexandriaNet_PacketDataBuffer:
    return AlexandriaNet_PacketDataBuffer.new()

  func deserialize(data: AlexandriaNet_PacketDataBuffer) -> void:
    pass

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    return ERR_METHOD_NOT_FOUND

## Dummy packet which is used to initiate the TCP connection
class GreetingPacket extends Packet:
  static func get_name() -> StringName:
    return &"GreetingPacket"

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    print(sender.get_connected_host(), ":", sender.get_connected_port(), " -> Greeted!")
    return OK

## Requests a database entry from the remote AlexandriaNetServer
class DatabaseReadRequestPacket extends Packet:
  var schema_name: String
  var entry_name: String
  var create_if_does_not_exist := false

  static func get_name() -> StringName:
    return &"DatabaseReadRequestPacket"

  func serialize() -> AlexandriaNet_PacketDataBuffer:
    var data := AlexandriaNet_PacketDataBuffer.new()
    data.write_utf8_string(schema_name)
    data.write_utf8_string(entry_name)
    data.write_u8(create_if_does_not_exist)
    return data

  func deserialize(data: AlexandriaNet_PacketDataBuffer) -> void:
    schema_name = data.read_utf8_string()
    entry_name = data.read_utf8_string()
    create_if_does_not_exist = data.read_u8()

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    var response_packet := DatabaseReadResponsePacket.new()
    response_packet.schema_name = schema_name
    response_packet.entry_name = entry_name
    if net.is_server():
      var schema_data := Alexandria.get_schema_data(schema_name)
      if schema_data:
        if create_if_does_not_exist and not schema_data.has_entry(entry_name):
          schema_data.create_entry(entry_name)
        var entry_data := schema_data.serialize_entry(entry_name)
        if entry_data.size() > 0:
          response_packet.entry_data = entry_data
          response_packet.code = OK
        else:
          response_packet.code = ERR_DATABASE_CANT_READ
      else:
        response_packet.code = ERR_INVALID_PARAMETER
    else:
      response_packet.code = ERR_QUERY_FAILED
    sender.put_packet(net.serialize_packet(response_packet).raw_bytes())
    return response_packet.code

## Requests a database entry from the remote AlexandriaNetServer
class DatabaseReadResponsePacket extends Packet:
  var code: Error = ERR_UNCONFIGURED
  var schema_name: String
  var entry_name: String
  var entry_data: PackedByteArray

  static func get_name() -> StringName:
    return &"DatabaseReadResponsePacket"

  func serialize() -> AlexandriaNet_PacketDataBuffer:
    var data := AlexandriaNet_PacketDataBuffer.new()
    data.write_u8(code)
    data.write_utf8_string(schema_name)
    data.write_utf8_string(entry_name)
    data.write_byte_array(entry_data)
    return data

  func deserialize(data: AlexandriaNet_PacketDataBuffer) -> void:
    code = data.read_u8()
    schema_name = data.read_utf8_string()
    entry_name = data.read_utf8_string()
    entry_data = data.read_byte_array()

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    if not net.is_client():
      return ERR_METHOD_NOT_FOUND
    var schema_data := Alexandria.get_schema_data(schema_name)
    if not schema_data:
      return ERR_INVALID_PARAMETER
    var entry := schema_data.deserialize_entry(entry_data)
    if not entry:
      return ERR_CANT_RESOLVE
    net.got_database_entry.emit(schema_name, entry_name, entry)
    return OK

## Requests a database entry to be created or updated on the remote AlexandriaNetServer
class DatabaseWriteRequestPacket extends Packet:
  var schema_name: String
  var entry_name: String
  var entry_data: PackedByteArray

  static func get_name() -> StringName:
    return &"DatabaseWriteRequestPacket"

  func serialize() -> AlexandriaNet_PacketDataBuffer:
    var data := AlexandriaNet_PacketDataBuffer.new()
    data.write_utf8_string(schema_name)
    data.write_utf8_string(entry_name)
    data.write_byte_array(entry_data)
    return data

  func deserialize(data: AlexandriaNet_PacketDataBuffer) -> void:
    schema_name = data.read_utf8_string()
    entry_name = data.read_utf8_string()
    entry_data = data.read_byte_array()

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    if not net.is_server():
      return ERR_METHOD_NOT_FOUND
    var schema_data := Alexandria.get_schema_data(schema_name)
    if not schema_data:
      return ERR_INVALID_PARAMETER
    if not schema_data.has_entry(entry_name):
      match schema_data.create_entry(entry_name):
        OK:
          pass
        var error:
          return ERR_DATABASE_CANT_WRITE
    var new_entry := schema_data.deserialize_entry(entry_data)
    if not new_entry:
      return ERR_CANT_RESOLVE
    return schema_data.update_entry(entry_name, new_entry)

var packet_types := [
  GreetingPacket,
  DatabaseReadRequestPacket,
  DatabaseReadResponsePacket,
  DatabaseWriteRequestPacket,
]

func is_server() -> bool:
  return false

func is_client() -> bool:
  return false

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

signal got_database_entry(schema_name: String, entry_name: String, entry: Resource)
