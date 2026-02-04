class_name TileLibrary extends Node

var lib: Dictionary[String, TileDef] = {}
var by_area: Dictionary[String, Array] = {} #Array[TileDef]

@export var tilemap_layer: TileMapLayer

func _ready() -> void:
	build_tile_library(tilemap_layer)

func build_tile_library(tilemap_layer: TileMapLayer):
	var tile_set := tilemap_layer.tile_set
	# Iterate all sources (atlas + scenes) in the TileSet
	for source_index in tile_set.get_source_count():
		var source: TileSetAtlasSource = tile_set.get_source(source_index)
		# Only process TileSetAtlasSource
		if not source is TileSetAtlasSource:
			continue
		# Iterate the tile coords IDs in this atlas source
		for i in range(source.get_tiles_count()):
			var atlas_coords = source.get_tile_id(i)
			# For each alternative ID this tile has (this includes 0 aka the base tile)
			var alt_count := source.get_alternative_tiles_count(atlas_coords)
			for alt_index in range(alt_count):
				# Fetch TileData for this alternative
				var tile_data := source.get_tile_data(atlas_coords, alt_index)
				if tile_data == null:
					continue
				# Read the custom "tile_name" tag from the TileData
				var type_tag = tile_data.get_custom_data("tile_name")
				# Only index tiles with this tag
				if type_tag != null:
					# Create the TileDef with source + coords + alternative
					var def := TileDef.new(
						source_index,
						atlas_coords,
						alt_index
					)
					lib[str(type_tag)] = def
					# Create "sub-tilesets" for room types
					var area_tag = tile_data.get_custom_data("area")
					if area_tag != null:
						if not by_area.has(area_tag):
							by_area[area_tag] = []
						by_area[area_tag].append(def)




# OLD VERSION just kept for reference because maybe I want to do something similar
# Where it actually makes sense to do so
#@export_group("Blocks")
#@export var wall_block : TileDef
#@export var floor: TileDef
#
#@export_group("Walls")
#@export var wall: TileDef
#@export var corner_1: TileDef # aka wall end
#@export var corner_2: TileDef
#@export var corner_3: TileDef
#@export var corner_4: TileDef
#@export var door: TileDef
