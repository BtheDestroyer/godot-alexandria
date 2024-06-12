class_name Alexandria_Entry extends Resource

enum Permissions {
  READ = 1,
  UPDATE = 2,
  DELETE = 4,

  NONE = 0,
  READ_UPDATE = READ | UPDATE,
  READ_UPDATE_DELETE = READ | UPDATE | DELETE,
}

@export var owner: Alexandria_User
@export var owner_permissions := Permissions.READ_UPDATE_DELETE
@export var everyone_permissions := Permissions.READ:
  get:
    if owner == null:
      return owner_permissions
    return everyone_permissions
