class_name Level extends Node2D

@onready var tile_layer_tilemap: TileMapLayer = $TileLayer #TODO: we might not use this
@onready var wall_layer_tilemap: TileMapLayer = $WallLayer # This will probably contain floors aswell
@onready var highlight_layer_tilemap: TileMapLayer = $HighlightLayer

@onready var level_generator: LevelGenerator = $LevelGenerator
@onready var tile_library: Node = $TileLibrary

var level_data: LevelData

enum TileTransform {
	ROTATE_0 = 0,
	ROTATE_90 = TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H,
	ROTATE_180 = TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V,
	ROTATE_270 = TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V,
}

func grid_to_local(pos: Vector2i):
	return wall_layer_tilemap.map_to_local(pos)

func draw_grid() -> void:
	wall_layer_tilemap.clear()
	for y in range(level_data.grid.size.y):
		for x in range(level_data.grid.size.x):
			var tile: Tile = level_data.grid.get_cell(Vector2i(x, y))
			if tile == null:
				# wall_layer_tilemap.set_cell(Vector2i(x, y), -1) # Erase
				pass
			else:
				var tile_def = tile.definition
				var alt_tile_with_rotation = Tile.apply_tile_transform(tile_def.alternative_tile, tile.rotation)
				wall_layer_tilemap.set_cell(Vector2i(x, y), tile_def.source_id, tile_def.atlas_coords, alt_tile_with_rotation)


func generate_new_level(config: LevelGenerationConfig):
	level_data = level_generator.generate_level(config, tile_library)
