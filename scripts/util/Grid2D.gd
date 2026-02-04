class_name Grid2D extends RefCounted

var size: Vector2i
var cells: Array[Array]

@warning_ignore("shadowed_variable")
func _init(size: Vector2i, default = null):
	self.size = size
	cells = []
	cells.resize(size.y)
	for y in size.y:
		cells[y] = []
		cells[y].resize(size.x)
		cells[y].fill(default)

func get_cell(pos: Vector2i):
	return cells[pos.y][pos.x]

func set_cell(pos: Vector2i, value):
	cells[pos.y][pos.x] = value

func duplicate() -> Grid2D:
	var copy := Grid2D.new(size)
	for y in range(size.y):
		for x in range(size.x):
			copy.cells[y][x] = cells[y][x]
	return copy
