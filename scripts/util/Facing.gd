class_name Facing

enum Direction {
	UP,
	RIGHT,
	DOWN,
	LEFT
}

static func to_vector(dir: Direction) -> Vector2i:
	match dir:
		Direction.UP:
			return Vector2i.UP
		Direction.DOWN:
			return Vector2i.DOWN
		Direction.LEFT:
			return Vector2i.LEFT
		Direction.RIGHT:
			return Vector2i.RIGHT
		_:
			return Vector2i.ZERO
