class_name Utils extends RefCounted

static func random_rect_pos_safe(rect: Rect2i) -> Vector2i:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return rect.position

	return rect.position + Vector2i(
		randi() % rect.size.x,
		randi() % rect.size.y
	)

static func weighted_choice(seq:Array, weights:Array):
	## Select an element from seq with a bias specified by weights.
	##
	## weights: relative bias of each element of seq, must have the same number of
	## elements as seq. For example, to make the first item 3 times as likely to be selected and the
	## second one half as likely, you would pass weights = [3, 0.5, 1, 1 ..., 1].

	# inspired by the Python implementation of random.choices()
	var cumulative_weights = [0]
	var tot = 0
	assert(seq.size() == weights.size())
	for w in weights:
		tot += w
		cumulative_weights.append(tot)

	# weighted indexing with a random val
	var val = randf_range(0, tot)
	# This utilizes the fact that bsearch returns the position where the value has to be inserted
	# Then -1 to get the index that corresponds to the weight
	return seq[cumulative_weights.bsearch(val) - 1]
