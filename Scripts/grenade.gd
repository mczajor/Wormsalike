extends CharacterBody2D
class_name Grenade

## Thrown grenade: ballistic flight, bounces off terrain with damping, and
## explodes when its fuse runs out (never on contact).

signal exploded(world_pos: Vector2)
signal missed

const GRENADE_TEXTURE: Texture2D = preload("res://Assets/grenade.png")

var gravity: float = 900.0
var kill_y: float = INF
var fuse: float = 3.0

## Velocity kept after each bounce (0..1).
var bounciness: float = 0.55

var _spin: float = 0.0


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.5
	shape.shape = circle
	add_child(shape)


func launch(from: Vector2, initial_velocity: Vector2, shooter: PhysicsBody2D) -> void:
	global_position = from
	velocity = initial_velocity
	add_collision_exception_with(shooter)


func _physics_process(delta: float) -> void:
	fuse -= delta
	if fuse <= 0.0:
		exploded.emit(global_position)
		queue_free()
		return

	velocity.y += gravity * delta

	var collision := move_and_collide(velocity * delta)
	if collision != null:
		velocity = velocity.bounce(collision.get_normal()) * bounciness
		if velocity.length() < 20.0:
			velocity = Vector2.ZERO

	if global_position.y > kill_y + 50.0:
		missed.emit()
		queue_free()
		return

	# Rolls/spins proportionally to horizontal speed.
	_spin += velocity.x * delta * 0.08
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, _spin, Vector2.ONE)
	draw_texture(GRENADE_TEXTURE,
			-Vector2(GRENADE_TEXTURE.get_width(), GRENADE_TEXTURE.get_height()) * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Fuse countdown above the grenade, red in the final second.
	var seconds: int = ceili(fuse)
	var color := Color(1.0, 0.35, 0.3) if fuse <= 1.0 else Color.WHITE
	draw_string(ThemeDB.fallback_font, Vector2(-4.0, -10.0), str(seconds),
			HORIZONTAL_ALIGNMENT_CENTER, -1, 11, color)
