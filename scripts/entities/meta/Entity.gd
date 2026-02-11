class_name Entity extends Node2D

@export var is_blocking: bool = false
@export var pos: Vector2i = Vector2i(0,0) # Expanded pos
@export var level: Level

func _ready() -> void:
	if not level:
		push_error("Entity has no Level assigned")
		return
	# Move to starting position
	update_position()
	
func update_position(pos_p: Vector2i = pos) -> void:
	pos = pos_p
	position = level.grid_to_global(pos)
	

func _process(delta: float) -> void: # Same as update in unity
	pass

func _take_turn() -> void:
	pass
