class_name TileDef extends Resource

@export var source_id: int
@export var atlas_coords: Vector2i
@export var alternative_tile: int

func _init(p_source_id: int, p_atlas_coords: Vector2i, p_alternative_tile: int = 0) -> void:
	source_id = p_source_id
	atlas_coords = p_atlas_coords
	alternative_tile = p_alternative_tile

# These are replaced with the datalayers in the tilemap
#@export var is_walkable: bool = false
#@export var is_see_through: bool = false
