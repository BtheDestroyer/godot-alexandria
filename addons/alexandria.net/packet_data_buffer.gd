class_name AlexandriaNet_PacketDataBuffer extends RefCounted

var _bytes: PackedByteArray
var offset := 0
var origin

func _init(data := PackedByteArray()):
  _bytes = data.duplicate()

func slice(begin: int, end := 2147483647) -> AlexandriaNet_PacketDataBuffer:
  return new(_bytes.slice(begin, end))
func duplicate() -> AlexandriaNet_PacketDataBuffer:
  var duplicated := new(_bytes)
  duplicated.offset = offset
  return duplicated

func size() -> int:
  return _bytes.size()
func excess_size() -> int:
  return size() - offset
func raw_bytes() -> PackedByteArray:
  return _bytes

func peek_u8() -> int:
  var read := _bytes.decode_u8(offset)
  return read
func peek_s8() -> int:
  var read := _bytes.decode_s8(offset)
  return read
func peek_u16() -> int:
  var read := _bytes.decode_u16(offset)
  return read
func peek_s16() -> int:
  var read := _bytes.decode_s16(offset)
  return read
func peek_u32() -> int:
  var read := _bytes.decode_u32(offset)
  return read
func peek_s32() -> int:
  var read := _bytes.decode_s32(offset)
  return read
func peek_u64() -> int:
  var read := _bytes.decode_u64(offset)
  return read
func peek_s64() -> int:
  var read := _bytes.decode_s64(offset)
  return read
func peek_half() -> float:
  var read := _bytes.decode_half(offset)
  return read
func peek_float() -> float:
  var read := _bytes.decode_float(offset)
  return read
func peek_double() -> float:
  var read := _bytes.decode_double(offset)
  return read

func read_u8() -> int:
  var read := _bytes.decode_u8(offset)
  offset += 1
  return read
func read_s8() -> int:
  var read := _bytes.decode_s8(offset)
  offset += 1
  return read
func read_u16() -> int:
  var read := _bytes.decode_u16(offset)
  offset += 2
  return read
func read_s16() -> int:
  var read := _bytes.decode_s16(offset)
  offset += 2
  return read
func read_u32() -> int:
  var read := _bytes.decode_u32(offset)
  offset += 4
  return read
func read_s32() -> int:
  var read := _bytes.decode_s32(offset)
  offset += 4
  return read
func read_u64() -> int:
  var read := _bytes.decode_u64(offset)
  offset += 8
  return read
func read_s64() -> int:
  var read := _bytes.decode_s64(offset)
  offset += 8
  return read
func read_half() -> float:
  var read := _bytes.decode_half(offset)
  offset += 2
  return read
func read_float() -> float:
  var read := _bytes.decode_float(offset)
  offset += 4
  return read
func read_double() -> float:
  var read := _bytes.decode_double(offset)
  offset += 8
  return read
func read_Vector2() -> Vector2:
  return Vector2(read_float(), read_float())
func read_Vector3() -> Vector3:
  return Vector3(read_float(), read_float(), read_float())
func read_Vector4() -> Vector4:
  return Vector4(read_float(), read_float(), read_float(), read_float())
func read_byte_array() -> PackedByteArray:
  var size := read_u16()
  var read := _bytes.slice(offset, offset + size)
  offset += size
  return read
func read_u32_array() -> PackedInt32Array:
  var size := read_u16()
  var read: PackedInt32Array = []
  read.resize(size)
  for i in range(size):
    read[i] = read_u32()
  return read
func read_utf8_string() -> String:
  return read_byte_array().get_string_from_utf8()
func read_string() -> String:
  return read_utf8_string()
func read_packet_data_buffer() -> AlexandriaNet_PacketDataBuffer:
  return new(read_byte_array())

func resize(new_size: int):
  _bytes.resize(new_size)
  offset = min(offset, new_size)
func reserve(minimum_total_bytes: int):
  resize(max(_bytes.size(), minimum_total_bytes))
func reserve_more(additional_bytes: int):
  resize(_bytes.size() + additional_bytes)
func reserve_more_if_needed(additional_bytes: int):
  reserve(offset + additional_bytes)
func strip_excess():
  resize(offset)

func write_u8(value: int):
  reserve_more_if_needed(1)
  _bytes.encode_u8(offset, value)
  offset += 1
func write_s8(value: int):
  reserve_more_if_needed(1)
  _bytes.encode_s8(offset, value)
  offset += 1
func write_u16(value: int):
  reserve_more_if_needed(2)
  _bytes.encode_u16(offset, value)
  offset += 2
func write_s16(value: int):
  reserve_more_if_needed(2)
  _bytes.encode_s16(offset, value)
  offset += 2
func write_u32(value: int):
  reserve_more_if_needed(4)
  _bytes.encode_u32(offset, value)
  offset += 4
func write_s32(value: int):
  reserve_more_if_needed(4)
  _bytes.encode_s32(offset, value)
  offset += 4
func write_u64(value: int):
  reserve_more_if_needed(8)
  _bytes.encode_u64(offset, value)
  offset += 8
func write_s64(value: int):
  reserve_more_if_needed(8)
  _bytes.encode_s64(offset, value)
  offset += 8
func write_half(value: float):
  reserve_more_if_needed(4)
  _bytes.encode_half(offset, value)
  offset += 2
func write_float(value: float):
  reserve_more_if_needed(4)
  _bytes.encode_float(offset, value)
  offset += 4
func write_double(value: float):
  reserve_more_if_needed(8)
  _bytes.encode_double(offset, value)
  offset += 8
func write_Vector2(value: Vector2):
  reserve_more_if_needed(8)
  write_float(value.x)
  write_float(value.y)
func write_Vector3(value: Vector3):
  reserve_more_if_needed(12)
  write_float(value.x)
  write_float(value.y)
  write_float(value.z)
func write_Vector4(value: Vector4):
  reserve_more_if_needed(16)
  write_float(value.x)
  write_float(value.y)
  write_float(value.z)
  write_float(value.w)
func write_byte_array(value: PackedByteArray):
  var size := value.size()
  write_u16(size)
  reserve_more_if_needed(size)
  for byte in value:
    write_u8(byte)
func write_u32_array(value: PackedInt32Array):
  var size := value.size()
  write_u16(size)
  reserve_more_if_needed(size * 4)
  for i in value:
    write_u32(i)
func write_utf8_string(value: String):
  write_byte_array(value.to_utf8_buffer())
func write_string(value: String):
  write_utf8_string(value)
func write_packet_data_buffer(value: AlexandriaNet_PacketDataBuffer):
  write_byte_array(value._bytes)
func append_packet_data_buffer(value: AlexandriaNet_PacketDataBuffer):
  _bytes.append_array(value._bytes)
