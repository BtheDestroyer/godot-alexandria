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

## Base type of all packets which involve a database schema interaction
class DatabaseSchemaPacket extends Packet:
  var schema_name: String

  static func get_name() -> StringName:
    return &"DatabaseSchemaPacket"

  func _init(schema_name := "") -> void:
    self.schema_name = schema_name

  func serialize() -> AlexandriaNet_PacketDataBuffer:
    var data := AlexandriaNet_PacketDataBuffer.new()
    data.write_utf8_string(schema_name)
    return data

  func deserialize(data: AlexandriaNet_PacketDataBuffer) -> void:
    schema_name = data.read_utf8_string()

## Base type of packets which are a response to DatabaseEntryPackets
class DatabaseSchemaResponsePacket extends DatabaseSchemaPacket:
  var code: Error = ERR_UNCONFIGURED

  static func get_name() -> StringName:
    return &"DatabaseSchemaResponsePacket"

  func _init(packet: DatabaseSchemaPacket = null) -> void:
    if packet:
      super(packet.schema_name)

  func serialize() -> AlexandriaNet_PacketDataBuffer:
    var data := super()
    data.write_u8(code)
    return data

  func deserialize(data: AlexandriaNet_PacketDataBuffer) -> void:
    super(data)
    code = data.read_u8()

## Base type of all packets which involve a database entry interaction
class DatabaseEntryPacket extends DatabaseSchemaPacket:
  var entry_name: String

  static func get_name() -> StringName:
    return &"DatabaseEntryPacket"

  func _init(schema_name := "", entry_name := "") -> void:
    super(schema_name)
    self.entry_name = entry_name

  func serialize() -> AlexandriaNet_PacketDataBuffer:
    var data := super()
    data.write_utf8_string(entry_name)
    return data

  func deserialize(data: AlexandriaNet_PacketDataBuffer) -> void:
    super(data)
    entry_name = data.read_utf8_string()

## Base type of packets which are a response to DatabaseEntryPackets
class DatabaseEntryResponsePacket extends DatabaseEntryPacket:
  var code: Error = ERR_UNCONFIGURED

  static func get_name() -> StringName:
    return &"DatabaseEntryResponsePacket"

  func _init(packet: DatabaseEntryPacket = null) -> void:
    if packet:
      super(packet.schema_name, packet.entry_name)

  func serialize() -> AlexandriaNet_PacketDataBuffer:
    var data := super()
    data.write_u8(code)
    return data

  func deserialize(data: AlexandriaNet_PacketDataBuffer) -> void:
    super(data)
    code = data.read_u8()

## Requests a database entry to be created on the remote AlexandriaNetServer
class DatabaseCreateRequestPacket extends DatabaseEntryPacket:

  static func get_name() -> StringName:
    return &"DatabaseCreateRequestPacket"

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    var response_packet := DatabaseCreateResponsePacket.new(self)
    if net.is_server():
      var schema_data := Alexandria.get_schema_data(schema_name)
      if schema_data:
        response_packet.code = schema_data.create_entry(entry_name)
      else:
        response_packet.code = ERR_INVALID_PARAMETER
    else:
      response_packet.code = ERR_QUERY_FAILED
    sender.put_packet(net.serialize_packet(response_packet).raw_bytes())
    return response_packet.code

## Sent by AlexandriaNetServer in response to a DatabaseCreateRequestPacket
class DatabaseCreateResponsePacket extends DatabaseEntryResponsePacket:

  static func get_name() -> StringName:
    return &"DatabaseCreateResponsePacket"

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    if not net.is_client():
      return ERR_METHOD_NOT_FOUND
    net.created_database_entry_response.emit(schema_name, entry_name, code)
    return OK

## Requests a database entry from the remote AlexandriaNetServer
class DatabaseReadRequestPacket extends DatabaseEntryPacket:

  static func get_name() -> StringName:
    return &"DatabaseReadRequestPacket"

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    var response_packet := DatabaseReadResponsePacket.new(self)
    if net.is_server():
      var schema_data := Alexandria.get_schema_data(schema_name)
      if schema_data:
        if schema_data.has_entry(entry_name):
          var entry := schema_data.get_entry(entry_name)
          if entry:
            if Alexandria.get_entry_permissions_for_user(entry, net.get_connected_client_for_connection(sender).session_token.user) & Alexandria_Entry.Permissions.READ:
              var entry_data := schema_data.serialize_entry(entry_name, entry)
              if entry_data.size() > 0:
                response_packet.entry_data = entry_data
                response_packet.code = OK
              else:
                response_packet.code = ERR_CANT_RESOLVE
            else:
              response_packet.code = ERR_FILE_NO_PERMISSION
          else:
            response_packet.code = ERR_DATABASE_CANT_READ
        else:
          response_packet.code = ERR_DOES_NOT_EXIST
      else:
        response_packet.code = ERR_INVALID_PARAMETER
    else:
      response_packet.code = ERR_QUERY_FAILED
    sender.put_packet(net.serialize_packet(response_packet).raw_bytes())
    return response_packet.code

## Sent by AlexandriaNetServer in response to a DatabaseReadRequestPacket
class DatabaseReadResponsePacket extends DatabaseEntryResponsePacket:
  var entry_data: PackedByteArray

  static func get_name() -> StringName:
    return &"DatabaseReadResponsePacket"

  func serialize() -> AlexandriaNet_PacketDataBuffer:
    var data := super()
    data.write_byte_array(entry_data)
    return data

  func deserialize(data: AlexandriaNet_PacketDataBuffer) -> void:
    super(data)
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
    net.read_database_entry_response.emit(schema_name, entry_name, entry)
    return OK

## Requests a database entry to be updated on the remote AlexandriaNetServer
class DatabaseUpdateRequestPacket extends DatabaseEntryPacket:
  var entry_data: PackedByteArray

  static func get_name() -> StringName:
    return &"DatabaseUpdateRequestPacket"

  func serialize() -> AlexandriaNet_PacketDataBuffer:
    var data := super()
    data.write_byte_array(entry_data)
    return data

  func deserialize(data: AlexandriaNet_PacketDataBuffer) -> void:
    super(data)
    entry_data = data.read_byte_array()

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    var response_packet := DatabaseUpdateResponsePacket.new(self)
    if net.is_server():
      var schema_data := Alexandria.get_schema_data(schema_name)
      if schema_data:
        var new_entry := schema_data.deserialize_entry(entry_data)
        if new_entry:
          var can_write := true
          if new_entry is Alexandria_Entry:
            var existing_entry := schema_data.get_entry(entry_name)
            if existing_entry:
              can_write = Alexandria.get_entry_permissions_for_user(existing_entry, net.get_connected_client_for_connection(sender).session_token.user) & Alexandria_Entry.Permissions.UPDATE
          if can_write:
            response_packet.code = schema_data.update_entry(entry_name, new_entry)
          else:
            response_packet.code = ERR_FILE_NO_PERMISSION
        else:
          response_packet.code = ERR_CANT_RESOLVE
      else:
        response_packet.code = ERR_INVALID_PARAMETER
    else:
      response_packet.code = ERR_QUERY_FAILED
    sender.put_packet(net.serialize_packet(response_packet).raw_bytes())
    return response_packet.code

## Sent by AlexandriaNetServer in response to a DatabaseUpdateRequestPacket
class DatabaseUpdateResponsePacket extends DatabaseEntryResponsePacket:

  static func get_name() -> StringName:
    return &"DatabaseUpdateResponsePacket"

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    if not net.is_client():
      return ERR_METHOD_NOT_FOUND
    net.updated_database_entry_response.emit(schema_name, entry_name, code)
    return OK

## Requests a database entry to be deleted on the remote AlexandriaNetServer
class DatabaseDeleteRequestPacket extends DatabaseEntryPacket:

  static func get_name() -> StringName:
    return &"DatabaseDeleteRequestPacket"

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    var response_packet := DatabaseDeleteResponsePacket.new(self)
    if net.is_server():
      var schema_data := Alexandria.get_schema_data(schema_name)
      if schema_data:
        var can_delete := true
        var existing_entry := schema_data.get_entry(entry_name)
        if existing_entry is Alexandria_Entry:
          can_delete = Alexandria.get_entry_permissions_for_user(existing_entry, net.get_connected_client_for_connection(sender).session_token.user) & Alexandria_Entry.Permissions.DELETE
        if can_delete:
          response_packet.code = schema_data.delete_entry(entry_name)
        else:
          response_packet.code = ERR_FILE_NO_PERMISSION
      else:
        response_packet.code = ERR_INVALID_PARAMETER
    else:
      response_packet.code = ERR_QUERY_FAILED
    sender.put_packet(net.serialize_packet(response_packet).raw_bytes())
    return response_packet.code

## Sent by AlexandriaNetServer in response to a DatabaseDeleteRequestPacket
class DatabaseDeleteResponsePacket extends DatabaseEntryResponsePacket:

  static func get_name() -> StringName:
    return &"DatabaseDeleteResponsePacket"

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    if not net.is_client():
      return ERR_METHOD_NOT_FOUND
    net.deleted_database_entry_response.emit(schema_name, entry_name, code)
    return OK

## Requests a list of database entry for a given schema from the remote AlexandriaNetServer
class DatabaseSchemaEntriesRequestPacket extends DatabaseSchemaPacket:

  static func get_name() -> StringName:
    return &"DatabaseSchemaEntriesRequestPacket"

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    var response_packet := DatabaseSchemaEntriesResponsePacket.new(self)
    if net.is_server():
      var schema_data := Alexandria.get_schema_data(schema_name)
      if schema_data:
        response_packet.entries = schema_data.get_entries()
        response_packet.code = OK
      else:
        response_packet.code = ERR_INVALID_PARAMETER
    else:
      response_packet.code = ERR_QUERY_FAILED
    sender.put_packet(net.serialize_packet(response_packet).raw_bytes())
    return response_packet.code

## Sent by AlexandriaNetServer in response to a DatabaseSchemaEntriesRequestPacket
class DatabaseSchemaEntriesResponsePacket extends DatabaseSchemaResponsePacket:
  var entries: PackedStringArray

  static func get_name() -> StringName:
    return &"DatabaseSchemaEntriesResponsePacket"

  func serialize() -> AlexandriaNet_PacketDataBuffer:
    var data := super()
    data.write_u16(entries.size())
    for entry: String in entries:
      data.write_utf8_string(entry)
    return data

  func deserialize(data: AlexandriaNet_PacketDataBuffer) -> void:
    super(data)
    entries.resize(data.read_u16())
    for i: int in range(entries.size()):
      entries[i] = data.read_utf8_string()

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    if not net.is_client():
      return ERR_METHOD_NOT_FOUND
    net.database_schema_entries_response.emit(schema_name, entries)
    return OK

var packet_types := [
  DatabaseCreateRequestPacket,
  DatabaseCreateResponsePacket,
  DatabaseReadRequestPacket,
  DatabaseReadResponsePacket,
  DatabaseUpdateRequestPacket,
  DatabaseUpdateResponsePacket,
  DatabaseSchemaEntriesRequestPacket,
  DatabaseSchemaEntriesResponsePacket
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

signal created_database_entry_response(schema_name: String, entry_name: String, code: Error)
signal read_database_entry_response(schema_name: String, entry_name: String, entry: Resource)
signal updated_database_entry_response(schema_name: String, entry_name: String, code: Error)
signal deleted_database_entry_response(schema_name: String, entry_name: String, code: Error)
signal database_schema_entries_response(schema_name: String, entries: PackedStringArray)
