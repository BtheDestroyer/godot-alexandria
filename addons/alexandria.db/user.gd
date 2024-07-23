class_name Alexandria_User extends Resource

# Lots of spacing for forwards-compatibility
enum Rank {
  UNVALIDATED = 0, ## New, unvalidated user
  USER = 32, ## Normal user
  MODERATOR = 64, ## Moderation staff; can read everything
  ADMINISTRATOR = 96, ## Server admin; can read/write/delete everything
  DEVELOPER = 128 ## Server developer; has full permissions for everything
}

@export var email: String
@export var password_salt: PackedByteArray
@export var password_hash: PackedByteArray
@export var rank := Rank.USER
var session_tokens: Array[AlexandriaNet_SessionToken]

func get_username() -> String:
  return resource_path.get_file().get_basename()

func hash_password(password: String) -> PackedByteArray:
  var hash := HashingContext.new()
  hash.start(HashingContext.HASH_SHA256)
  hash.update(password_salt)
  hash.update(password.to_utf8_buffer())
  return hash.finish()

func update_password(new_password: String, new_salt := password_salt) -> void:
  password_salt = new_salt
  password_hash = hash_password(new_password)

func check_password(password: String) -> bool:
  return hash_password(password) == password_hash

func clean_expired_session_tokens() -> void:
  for token: AlexandriaNet_SessionToken in session_tokens.filter(func(token: AlexandriaNet_SessionToken): return token.is_expired()):
    session_tokens.erase(token)

func is_session_token_valid(session_token: AlexandriaNet_SessionToken) -> bool:
  if session_token.is_expired():
    return false
  for token: AlexandriaNet_SessionToken in session_tokens:
    if not token.is_expired() and token.id == session_token.id:
      return true
  return false
