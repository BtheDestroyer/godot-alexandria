class_name Alexandria_Transaction extends Resource

# Can be set by check_requirements to improve debugging
@export var error_reason: String

# Transactions must implement the following methods:

# Returns `true` if the transaction requirements are satisfied, `false` otherwise
func check_requirements() -> bool:
  return false

# Applies the transaction. This *must not fail*; any conditional checks must be done in `check_requirements`
func apply() -> void:
  pass

# Effective usage:
# if transaction.check_requirements():
#   transaction.apply()
