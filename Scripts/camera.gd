extends Camera2D

## Simple camera for previewing / playing the Worms map.
## Middle-mouse drag to pan, scroll wheel to zoom.

@export var zoom_speed:     float = 0.15
@export var zoom_min:       float = 0.3
@export var zoom_max:       float = 4.0
@export var pan_button:     MouseButton = MOUSE_BUTTON_MIDDLE

var _dragging: bool    = false
var _drag_origin: Vector2


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == pan_button:
			_dragging = event.pressed
			if _dragging:
				_drag_origin = event.position

		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(1.0 + zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / (1.0 + zoom_speed))

	elif event is InputEventMouseMotion and _dragging:
		position -= event.relative / zoom.x


func _zoom_by(factor: float) -> void:
	var new_z: float = clamp(zoom.x * factor, zoom_min, zoom_max)
	zoom = Vector2(new_z, new_z)
