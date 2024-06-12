class_name AlexandriaNet_SessionToken extends Resource

# 7 days
const LIFETIME := 7.0 * 24.0 * 60.0 * 60.0

@export var id := _Alexandria.uuid_v4()
@export var expiration: int
var user

func _init(user) -> void:
  self.user = user
  expiration = Time.get_unix_time_from_system() + LIFETIME

func is_expired() -> bool:
  return Time.get_unix_time_from_system() > expiration

func invalidate() -> void:
  expiration = 0
  if user == null:
    return
  user.session_tokens.erase(self)
