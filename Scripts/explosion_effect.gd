extends Node2D

## Spawned by GameManager at the point of an explosion.
## Draws an expanding white circle that fades out, then frees itself.

var _radius:     float = 0.0
var _max_radius: float = 40.0
var _duration:   float = 0.18   # seconds until fully gone
var _elapsed:    float = 0.0


func init(max_radius: float, duration: float = 0.18) -> void:
	_max_radius = max_radius
	_duration   = duration


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = _elapsed / _duration          # 0 → 1 over lifetime
	_radius = _max_radius * t
	# Fade from fully opaque to transparent as it expands
	var alpha: float = 1.0 - t
	draw_circle(Vector2.ZERO, _radius, Color(1, 1, 1, alpha))
