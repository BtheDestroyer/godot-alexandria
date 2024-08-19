class_name AlexandriaNet extends Node

var crypto := Crypto.new()

const DEFAULT_PORT := 34902

class Packet:

  static func get_name() -> StringName:
    return &"Packet"

  static func is_encrypted() -> bool:
    return true

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

## Base type of all packets which involve a database transaction
class DatabaseTransactionPacket extends Packet:
  var transaction_name: String

  static func get_name() -> StringName:
    return &"DatabaseTransactionPacket"

  func _init(transaction_name := "") -> void:
    self.transaction_name = transaction_name

  func serialize() -> AlexandriaNet_PacketDataBuffer:
    var data := super()
    data.write_utf8_string(transaction_name)
    return data

  func deserialize(data: AlexandriaNet_PacketDataBuffer) -> void:
    super(data)
    transaction_name = data.read_utf8_string()

## Base type of packets which are a response to DatabaseTransactionPackets
class DatabaseTransactionResponsePacket extends DatabaseTransactionPacket:
  var code: Error = ERR_UNCONFIGURED
  var error_reason: String

  static func get_name() -> StringName:
    return &"DatabaseTransactionResponsePacket"

  func _init(packet: DatabaseTransactionPacket = null, error_reason := "") -> void:
    if packet:
      super(packet.transaction_name)
    self.error_reason = error_reason

  func serialize() -> AlexandriaNet_PacketDataBuffer:
    var data := super()
    data.write_u8(code)
    data.write_utf8_string(error_reason)
    return data

  func deserialize(data: AlexandriaNet_PacketDataBuffer) -> void:
    super(data)
    code = data.read_u8()
    error_reason = data.read_utf8_string()

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    if not net.is_client():
      return ERR_METHOD_NOT_FOUND
    net.transaction_response.emit(transaction_name, code, error_reason)
    return OK

## Base type of all packets which involve a database transaction
class DatabaseTransactionRequestPacket extends DatabaseTransactionPacket:
  var transaction: Alexandria_Transaction

  static func get_name() -> StringName:
    return &"DatabaseTransactionRequestPacket"

  func _init(transaction: Alexandria_Transaction = null, transaction_name := ((transaction.get_script() as GDScript).resource_path.get_file().get_basename() if transaction else "")) -> void:
    super(transaction_name)
    self.transaction = transaction

  func serialize() -> AlexandriaNet_PacketDataBuffer:
    var data := super()
    var transaction_data := Alexandria.get_transaction_data(transaction_name)
    if transaction_data == null:
      push_error("Failed to serialize ", get_name(), " as \"", transaction_name, "\" didn't have registered transaction data")
      return null
    var serialized_data := transaction_data.serialize_transaction(transaction)
    data.write_byte_array(serialized_data)
    return data

  func deserialize(data: AlexandriaNet_PacketDataBuffer) -> void:
    super(data)
    var transaction_data := Alexandria.get_transaction_data(transaction_name)
    if transaction_data == null:
      push_error("Failed to deserialize ", get_name(), " as \"", transaction_name, "\" didn't have registered transaction data")
      transaction = null
      return
    var serialized_data := data.read_byte_array()
    transaction = transaction_data.deserialize_transaction(serialized_data)

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    var response_packet := DatabaseTransactionResponsePacket.new(self)
    if net.is_server():
      if transaction != null:
        if transaction.check_requirements():
          transaction.apply()
          response_packet.code = OK
        else:
          response_packet.error_reason = transaction.error_reason
          response_packet.code = ERR_FILE_MISSING_DEPENDENCIES
      else:
        response_packet.code = ERR_INVALID_PARAMETER
    else:
      response_packet.code = ERR_QUERY_FAILED
    sender.put_packet(net.serialize_packet(response_packet).raw_bytes())
    return response_packet.code

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
        if response_packet.code == OK:
          var entry_data := schema_data.get_entry(entry_name)
          if entry_data is Alexandria_Entry:
            var connected_client = net.get_connected_client_for_connection(sender)
            if connected_client != null:
              var session_token: AlexandriaNet_SessionToken = connected_client.session_token
              if session_token != null:
                entry_data.owner = session_token.user
                response_packet.code = schema_data.update_entry(entry_name, entry_data)
              else:
                response_packet.code = ERR_UNAUTHORIZED
            else:
              response_packet.code = ERR_UNAUTHORIZED
            if response_packet.code != OK:
              schema_data.delete_entry(entry_name)
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
            var connected_client = net.get_connected_client_for_connection(sender)
            if connected_client != null:
              var session_token: AlexandriaNet_SessionToken = connected_client.session_token
              if session_token != null:
                if Alexandria.get_entry_permissions_for_user(entry, session_token.user) & Alexandria_Entry.Permissions.READ:
                  var entry_data := schema_data.serialize_entry(entry_name, entry, true)
                  if entry_data.size() > 0:
                    response_packet.entry_data = entry_data
                    response_packet.code = OK
                  else:
                    response_packet.code = ERR_CANT_RESOLVE
                else:
                  response_packet.code = ERR_FILE_NO_PERMISSION
              else:
                response_packet.code = ERR_UNAUTHORIZED
            else:
              response_packet.code = ERR_UNAUTHORIZED
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
    net.read_database_entry_response.emit(schema_name, entry_name, entry)
    if not entry:
      return ERR_CANT_RESOLVE
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

## Public key provided by AlexandriaNetServer to enable encrypted traffic to the server
class PublicKeyPacket extends Packet:
  var key := CryptoKey.new()

  static func get_name() -> StringName:
    return &"PublicKeyPacket"

  static func is_encrypted() -> bool:
    return false

  func serialize() -> AlexandriaNet_PacketDataBuffer:
    var data := super()
    data.write_utf8_string(key.save_to_string(true))
    return data

  func deserialize(data: AlexandriaNet_PacketDataBuffer) -> void:
    super(data)
    key.load_from_string(data.read_utf8_string(), true)

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    if not net.is_client():
      return ERR_METHOD_NOT_FOUND
    net.remote_public_key = key
    return OK

## Packet involving a user or session interaction
class UserPacket extends Packet:
  var username: String

  static func get_name() -> StringName:
    return &"UserPacket"

  func _init(packet: UserPacket = null) -> void:
    if packet:
      username = packet.username

  func serialize() -> AlexandriaNet_PacketDataBuffer:
    var data := super()
    data.write_utf8_string(username)
    return data

  func deserialize(data: AlexandriaNet_PacketDataBuffer) -> void:
    super(data)
    username = data.read_utf8_string()

## Sent by AlexandriaNetClient to request a user or session interaction
class UserRequestPacket extends UserPacket:
  var password: String

  static func get_name() -> StringName:
    return &"UserRequestPacket"

  func serialize() -> AlexandriaNet_PacketDataBuffer:
    var data := super()
    data.write_utf8_string(password)
    return data

  func deserialize(data: AlexandriaNet_PacketDataBuffer) -> void:
    super(data)
    password = data.read_utf8_string()

## Sent by AlexandriaNetServer in response to a UserRequestPacket
class UserResponsePacket extends UserPacket:
  var code: Error = ERR_UNCONFIGURED

  static func get_name() -> StringName:
    return &"UserResponsePacket"

  func _init(packet: UserRequestPacket = null) -> void:
    super(packet)

  func serialize() -> AlexandriaNet_PacketDataBuffer:
    var data := super()
    data.write_u8(code)
    return data

  func deserialize(data: AlexandriaNet_PacketDataBuffer) -> void:
    super(data)
    code = data.read_u8()

## Request by AlexandriaNetClient to request a new user be created
class CreateUserRequestPacket extends UserRequestPacket:

  static func get_name() -> StringName:
    return &"CreateUserRequestPacket"

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    var response_packet := CreateUserResponsePacket.new(self)
    if net.is_server():
      response_packet.code = net.create_user(username)
      if response_packet.code == OK:
        var user: Alexandria_User = net.get_user(username)
        user.update_password(password)
        response_packet.code = ResourceSaver.save(user)
    else:
      response_packet.code = ERR_QUERY_FAILED
    sender.put_packet(net.serialize_packet(response_packet).raw_bytes())
    return response_packet.code

## Sent by AlexandriaNetServer in response to a LoginRequestPacket
class CreateUserResponsePacket extends UserResponsePacket:

  static func get_name() -> StringName:
    return &"CreateUserResponsePacket"

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    if not net.is_client():
      return ERR_METHOD_NOT_FOUND
    net.create_user_response.emit(username, code)
    return OK

## Request by AlexandriaNetClient to initiate a user session
class LoginRequestPacket extends UserRequestPacket:

  static func get_name() -> StringName:
    return &"LoginRequestPacket"

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    var response_packet := LoginResponsePacket.new(self)
    if net.is_server():
      var connected_client = net.get_connected_client_for_connection(sender)
      if connected_client != null:
        connected_client.session_token = net.attempt_login(username, password)
        if connected_client.session_token:
          response_packet.code = OK
        else:
          response_packet.code = ERR_INVALID_PARAMETER
      else:
        response_packet.code = ERR_CONNECTION_ERROR
    else:
      response_packet.code = ERR_QUERY_FAILED
    sender.put_packet(net.serialize_packet(response_packet).raw_bytes())
    return response_packet.code

## Sent by AlexandriaNetServer in response to a LoginRequestPacket
class LoginResponsePacket extends UserResponsePacket:

  static func get_name() -> StringName:
    return &"LoginResponsePacket"

  func _init(packet: LoginRequestPacket = null) -> void:
    if packet:
      username = packet.username

  func handle(sender: AlexandriaNet_PacketPeerTCP, net: AlexandriaNet) -> Error:
    if not net.is_client():
      return ERR_METHOD_NOT_FOUND
    net.login_response.emit(username, code)
    return OK

var packet_types := [
  PublicKeyPacket,
  DatabaseTransactionRequestPacket,
  DatabaseTransactionResponsePacket,
  DatabaseCreateRequestPacket,
  DatabaseCreateResponsePacket,
  DatabaseReadRequestPacket,
  DatabaseReadResponsePacket,
  DatabaseUpdateRequestPacket,
  DatabaseUpdateResponsePacket,
  DatabaseDeleteRequestPacket,
  DatabaseDeleteResponsePacket,
  DatabaseSchemaEntriesRequestPacket,
  DatabaseSchemaEntriesResponsePacket,
  CreateUserRequestPacket,
  CreateUserResponsePacket,
  LoginRequestPacket,
  LoginResponsePacket
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
  var packet_bytes := packet.serialize()
  if is_client() and packet.is_encrypted():
    packet_bytes._bytes = crypto.encrypt(self.remote_public_key, packet_bytes._bytes)
  data.write_packet_data_buffer(packet_bytes)
  return data

func deserialize_packet(data: AlexandriaNet_PacketDataBuffer) -> Packet:
  var id := data.read_u16()
  var packet: Packet = packet_types[id].new()
  var packet_bytes := data.read_packet_data_buffer()
  if is_server() and packet.is_encrypted():
    packet_bytes._bytes = crypto.decrypt(self.crypto_key, packet_bytes._bytes)
  packet.deserialize(packet_bytes)
  return packet

signal created_database_entry_response(schema_name: String, entry_name: String, code: Error)
signal read_database_entry_response(schema_name: String, entry_name: String, entry: Resource)
signal updated_database_entry_response(schema_name: String, entry_name: String, code: Error)
signal deleted_database_entry_response(schema_name: String, entry_name: String, code: Error)
signal database_schema_entries_response(schema_name: String, entries: PackedStringArray)
signal transaction_response(transaction_name: String, code: Error, error_reason: String)
signal create_user_response(username: String, code: Error)
signal login_response(username: String, code: Error)
