extends CharacterBody2D
class_name Worm

## A single worm. Accepts input when [member is_active] is true.
## Controls: A/Left = left, D/Right = right, Space/W/Up = jump.

@export var move_speed:    float = 180.0
@export var jump_velocity: float = -420.0
@export var gravity:       float = 900.0
@export var radius:        float = 10.0

@export var is_active: bool = true:
	set(value):
		is_active = value
		queue_redraw()

var _jump_queued: bool = false


func _input(event: InputEvent) -> void:
	if not is_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode
		if kc == KEY_SPACE or kc == KEY_W or kc == KEY_UP:
			_jump_queued = true


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	var dir: float = 0.0
	if is_active:
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			dir -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			dir += 1.0

	if _jump_queued and is_on_floor():
		velocity.y = jump_velocity
	_jump_queued = false

	# Preserve horizontal knockback: if player isn't pressing a direction,
	# let existing velocity bleed off via friction rather than snapping to 0.
	if dir != 0.0:
		velocity.x = dir * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)

	move_and_slide()


func _draw() -> void:
	var body_color: Color = Color("d93f3f") if is_active else Color("8a5a5a")
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color("3a1010"), 1.5)
