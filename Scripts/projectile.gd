extends CharacterBody2D
class_name Projectile

signal exploded(world_pos: Vector2)
signal missed

const ROCKET_TEXTURE: Texture2D = preload("res://Assets/rocket.png")
const MAX_LIFETIME: float = 10.0

var gravity: float = 900.0
var kill_y: float = INF

var _age: float = 0.0
var _flame_t: float = 0.0


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	shape.shape = circle
	add_child(shape)
	_add_smoke_trail()


func launch(from: Vector2, initial_velocity: Vector2, shooter: PhysicsBody2D) -> void:
	global_position = from
	velocity = initial_velocity
	rotation = velocity.angle()
	add_collision_exception_with(shooter)


func _physics_process(delta: float) -> void:
	velocity.y += gravity * delta
	rotation = velocity.angle()

	var collision := move_and_collide(velocity * delta)
	if collision != null:
		exploded.emit(collision.get_position())
		queue_free()
		return

	_age += delta
	if global_position.y > kill_y + 50.0 or _age > MAX_LIFETIME:
		missed.emit()
		queue_free()
		return

	_flame_t += delta * 40.0
	queue_redraw()


func _draw() -> void:
	var flame_len: float = 7.0 + 3.5 * sin(_flame_t)
	var back_x: float = -ROCKET_TEXTURE.get_width() * 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(back_x, -2.5),
		Vector2(back_x, 2.5),
		Vector2(back_x - flame_len, 0.0),
	]), Color(1.0, 0.62, 0.1, 0.9))
	draw_colored_polygon(PackedVector2Array([
		Vector2(back_x, -1.2),
		Vector2(back_x, 1.2),
		Vector2(back_x - flame_len * 0.55, 0.0),
	]), Color(1.0, 0.9, 0.4, 0.95))

	draw_texture(ROCKET_TEXTURE,
			Vector2(-ROCKET_TEXTURE.get_width() * 0.5, -ROCKET_TEXTURE.get_height() * 0.5))


func _add_smoke_trail() -> void:
	var smoke := CPUParticles2D.new()
	smoke.local_coords = false
	smoke.amount = 40
	smoke.lifetime = 0.7
	smoke.direction = Vector2.ZERO
	smoke.spread = 180.0
	smoke.initial_velocity_min = 2.0
	smoke.initial_velocity_max = 8.0
	smoke.gravity = Vector2(0.0, -12.0)
	smoke.scale_amount_min = 1.5
	smoke.scale_amount_max = 3.0
	smoke.color = Color(0.85, 0.85, 0.85, 0.5)

	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.9, 0.9, 0.9, 0.55))
	ramp.set_color(1, Color(0.7, 0.7, 0.7, 0.0))
	smoke.color_ramp = ramp

	smoke.z_index = -1
	add_child(smoke)
