@tool
class_name LayeredProgressBar
extends Control

## A stacked progress bar: each layer is a slice of one total, drawn left to
## right (e.g. completed, has a candidate, remaining).

@export var bar_height := 22.0

var layers: Array[Dictionary] = []   # {"value": int, "color": Color}
var total := 0


func set_layers(new_layers: Array[Dictionary], new_total: int) -> void:
	layers = new_layers
	total = new_total
	queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(120, bar_height)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(size.x, bar_height))
	draw_rect(rect, Color("1b222c"))
	if total > 0:
		var x := 0.0
		for layer in layers:
			var width := size.x * float(layer.get("value", 0)) / float(total)
			if width > 0.0:
				draw_rect(Rect2(x, 0, width, bar_height), layer.get("color", Color.GRAY))
				x += width
	draw_rect(rect, Color("4a5666"), false, 1.0)
