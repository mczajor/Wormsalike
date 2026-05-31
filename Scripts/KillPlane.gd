extends Node2D
class_name KillPlane

## A rising kill plane. Owns its own world-space Y, draws itself as a
## semi-transparent band, and slides upward when told a round has ended.
## Worms read [method get_kill_y] each frame to decide if they've fallen in.

## How far up (world pixels) the plane moves each time it rises.
@export var rise_per_round: float = 35.0

## Seconds the slide-up animation takes.
@export var rise_duration: float = 0.6

@export var plane_color: Color = Color(0.85, 0.1, 0.1, 0.45)

## Tiled (repeated) texture drawn across the band. Falls back to plane_color
## if null. The texture's import settings must have Repeat enabled.
var texture: Texture2D = null

## Horizontal span and how far down the band is drawn. Set by the GameManager.
var span_left:  float = 0.0
var span_width: float = 0.0
var draw_depth: float = 1000.0

var _target_y: float = INF   # where the top of the plane is sliding toward
var _current_y: float = INF  # where it's drawn right now
var _rising: bool = false


## Initialise the plane at a given world-space Y (top edge of the band).
func setup(start_y: float, left: float, width: float, depth: float) -> void:
	_target_y   = start_y
	_current_y  = start_y
	span_left   = left
	span_width  = width
	draw_depth  = depth
	queue_redraw()


## Current kill threshold — worms below this Y die.
func get_kill_y() -> float:
	return _current_y


## Raise the plane by one round's worth and animate the slide.
func rise() -> void:
	_target_y -= rise_per_round
	_rising = true


func _process(delta: float) -> void:
	if not _rising:
		return
	# Move current toward target at a constant speed derived from the duration.
	var speed: float = rise_per_round / maxf(rise_duration, 0.01)
	_current_y = move_toward(_current_y, _target_y, speed * delta)
	queue_redraw()
	if is_equal_approx(_current_y, _target_y):
		_current_y = _target_y
		_rising = false


func _draw() -> void:
	if _current_y == INF:
		return
	var rect := Rect2(
		Vector2(span_left, _current_y),
		Vector2(span_width, draw_depth)
	)
	if texture != null:
		# tile = true repeats the texture across the rect instead of stretching.
		draw_texture_rect(texture, rect, true)
	else:
		draw_rect(rect, plane_color)
