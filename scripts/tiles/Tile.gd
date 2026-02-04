class_name Tile extends Resource

@export var definition: TileDef
@export var rotation: TileTransforms

enum TileTransforms {
	ROTATE_0 = 0,
	ROTATE_90 = TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H,
	ROTATE_180 = TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V,
	ROTATE_270 = TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V,
	FLIP_H = TileSetAtlasSource.TRANSFORM_FLIP_H,
	FLIP_V = TileSetAtlasSource.TRANSFORM_FLIP_V,
	FLIP_90_H = TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V,
	FLIP_90_V = TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V
}

func _init(p_definition: TileDef, p_rotation=TileTransforms.ROTATE_0) -> void:
	definition = p_definition
	rotation = p_rotation

static func apply_tile_transform(alternate_tile: int, tile_transform: TileTransforms):
	return alternate_tile | int(tile_transform)
