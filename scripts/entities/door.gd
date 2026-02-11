class_name Door extends Entity

@onready var sprite = $Sprite2D

var _is_open: bool = false

var facing: Facing.Direction = Facing.Direction.RIGHT
var is_right_handed: bool = true

var closed_position: Vector2i
var open_position: Vector2i
const open_offset: Vector2 = Vector2(-3,3)
var closed_facing: Facing.Direction
var open_facing: Facing.Direction

func _ready() -> void:
	super._ready()
	is_blocking = true
	closed_position = pos
	open_position = _get_open_position()
	closed_facing = facing
	open_facing = _get_open_facing()
	rotation_degrees = Facing.to_degrees(facing)
	
func _get_open_position() -> Vector2i:
	var facing_vector: Vector2i = Facing.to_vector(facing)
	if is_right_handed:
		return pos + facing_vector + Vector2i(facing_vector.y, facing_vector.x)
	else:
		return pos + facing_vector + Vector2i(-facing_vector.y, -facing_vector.x)

func _get_open_facing() -> Facing.Direction:
	if is_right_handed:
		return (facing+1)%Facing.Direction.size()
	else:
		return (facing-1)%Facing.Direction.size()

func toggle():
	print("TOGGLE!")
	if _is_open:
		close()
	else:
		open()

func open():
	if _is_open:
		return
	_is_open = true
	# Move position and adjust visual offset
	update_position(open_position)
	facing = open_facing
	rotation_degrees = Facing.to_degrees(facing)
	sprite.position = open_offset

func close():
	if not _is_open:
		return
	_is_open = false
	# Move position and adjust visual offset
	update_position(closed_position)
	facing = closed_facing
	rotation_degrees = Facing.to_degrees(facing)
	sprite.position = Vector2.ZERO

func get_is_open() -> bool:
	return _is_open


func _on_button_pressed() -> void:
	toggle()
