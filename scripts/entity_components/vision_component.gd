class_name VisionComponent
extends Node2D

@export var cone_angle: int = 90
@export var cone_direction: int = 90
@export var cone_length: int = 5

# We can reuse this for cameras and guards

func scan_vision(our_pos: Vector2i, level: Level):
	# TODO: If we see player return player pos Vector2i
	# else:
	return null

func draw_vision(our_pos: Vector2i, level: Level):
	# TODO: highlight vision on tiles
	pass
