extends CharacterBody2D
class_name Worm

## A single worm. Accepts input only when [member is_active] is true.
## Controls: A/Left = move left, D/Right = move right, Space/W/Up = jump.

@export var move_speed:    float = 90.0
@export var jump_velocity: float = -260.0
@export var gravity:       float = 900.0
@export var radius:        float = 10.0

@export var max_health: float = 100.0
var health: float = 100.0

## Set by GameManager — which player owns this worm (0-based).
var player_id: int = 0

## Set by GameManager — color that identifies this worm's owner.
var player_color: Color = Color("4a90d9")

@export var is_active: bool = false:
	set(value):
		is_active = value
		queue_redraw()

## Set by GameManager — the rising kill plane. The worm dies when it falls
## below the plane's current Y. Null means no kill plane (never dies this way).
var kill_plane: KillPlane = null

## Emitted when this worm crosses the kill plane.
## GameManager connects to this to remove the worm from the team.
signal died(worm: Worm)

## Set by GameManager during the post-shot delay. When true the worm ignores
## movement and jump input but still obeys gravity and knockback.
var input_locked: bool = false

var _jump_queued: bool = false

# Arrow bob animation state.
var _bob_t: float = 0.0
const _BOB_SPEED:     float = 3.0   # radians per second
const _BOB_AMPLITUDE: float = 2.0   # pixels of vertical travel


func _ready() -> void:
	health = max_health


## Apply a fixed amount of damage. Returns true if this brought the worm to 0.
## Does NOT emit [signal died] — the caller decides when to process the death,
## so damage can be applied safely while iterating over team arrays.
func take_damage(amount: float) -> bool:
	if health <= 0.0:
		return false   # already dead
	health = maxf(0.0, health - amount)
	queue_redraw()
	return health <= 0.0


## Emit the death signal. Called by the GameManager after damage resolution.
func kill() -> void:
	died.emit(self)


func _input(event: InputEvent) -> void:
	if not is_active or input_locked:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode
		if kc == KEY_SPACE or kc == KEY_W or kc == KEY_UP:
			_jump_queued = true


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	var dir: float = 0.0
	if is_active and not input_locked:
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			dir -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			dir += 1.0

	if _jump_queued and is_on_floor():
		velocity.y = jump_velocity
	_jump_queued = false

	if dir != 0.0:
		velocity.x = dir * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)

	move_and_slide()

	if kill_plane != null and global_position.y > kill_plane.get_kill_y():
		died.emit(self)

	# Keep the arrow bobbing while this worm is active.
	if is_active:
		_bob_t += delta * _BOB_SPEED
		queue_redraw()


func _draw() -> void:
	# Body is always drawn in the player's team color.
	draw_circle(Vector2.ZERO, radius, player_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0, 0, 0, 0.45), 1.5)

	_draw_health_bar()

	if not is_active:
		return

	# --- selection arrow ---
	# Sits above the worm's head and bobs up/down gently.
	var bob_offset: float = sin(_bob_t) * _BOB_AMPLITUDE
	var tip_y: float = -(radius + 18.0 + bob_offset)   # pointy bottom of the arrow

	const ARROW_H: float = 7.0    # height of the triangle
	const ARROW_W: float = 8.0    # half-width of the base

	# Downward-pointing triangle: base on top, tip at the bottom.
	var p_left  := Vector2(-ARROW_W, tip_y - ARROW_H)
	var p_right := Vector2( ARROW_W, tip_y - ARROW_H)
	var p_tip   := Vector2(0.0,      tip_y)

	# Filled white triangle.
	draw_colored_polygon(PackedVector2Array([p_left, p_right, p_tip]), Color.WHITE)
	# Thin dark outline so the arrow reads against any background.
	draw_polyline(PackedVector2Array([p_left, p_right, p_tip, p_left]),
				  Color(0, 0, 0, 0.5), 1.0)


func _draw_health_bar() -> void:
	const BAR_W: float = 24.0
	const BAR_H: float = 4.0
	var bar_y: float = -(radius + 10.0)
	var top_left := Vector2(-BAR_W * 0.5, bar_y)

	# Background (dark).
	draw_rect(Rect2(top_left, Vector2(BAR_W, BAR_H)), Color(0, 0, 0, 0.6))

	# Fill, colored green→yellow→red as health drops.
	var frac: float = clampf(health / max_health, 0.0, 1.0)
	var fill_color: Color
	if frac > 0.5:
		fill_color = Color(0.3, 0.85, 0.3)   # green
	elif frac > 0.25:
		fill_color = Color(0.9, 0.8, 0.2)    # yellow
	else:
		fill_color = Color(0.9, 0.25, 0.25)  # red
	draw_rect(Rect2(top_left, Vector2(BAR_W * frac, BAR_H)), fill_color)

	# Thin outline.
	draw_rect(Rect2(top_left, Vector2(BAR_W, BAR_H)), Color(0, 0, 0, 0.5), false, 1.0)
