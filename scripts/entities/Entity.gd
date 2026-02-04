class_name Entity
extends Node2D

@export var is_blocking: bool = false
var pos: Vector2i = Vector2i(0,0) # Expanded pos
@export var level: Level

func _ready() -> void:
	# Move to starting position
	position = level.grid_to_local(pos)

func _process(delta: float) -> void: # Same as update in unity
	pass

func _take_turn() -> void:
	pass
