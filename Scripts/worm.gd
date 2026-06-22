extends CharacterBody2D
class_name Worm

## A single worm. Accepts input only when [member is_active] is true.
## Controls: A/Left = move left, D/Right = move right, Space/W/Up = jump,
## Shift = toggle jetpack. While the jetpack is on, walking is disabled:
## W/Up thrusts upward, A/D thrusts sideways, and thrusting burns fuel.

@export var move_speed:    float = 90.0
@export var jump_velocity: float = -260.0
@export var gravity:       float = 900.0
@export var radius:        float = 10.0

@export var max_health: float = 100.0
var health: float = 100.0

## Landing faster than this (px/s downward) starts dealing fall damage.
@export var fall_damage_min_speed: float = 450.0
## Damage per px/s of impact speed above the threshold.
@export var fall_damage_scale: float = 0.08

## Jetpack: seconds of thrust available each turn (refilled by GameManager).
@export var jetpack_max_fuel: float = 5.0
## Upward acceleration while thrusting — must beat gravity to climb.
@export var jetpack_thrust: float = 1800.0
## Fastest the jetpack can push the worm upward (px/s).
@export var jetpack_max_rise_speed: float = 220.0
## Sideways acceleration while thrusting laterally.
@export var jetpack_lateral_thrust: float = 700.0
## Fastest lateral speed the jetpack can reach (px/s).
@export var jetpack_max_lateral_speed: float = 200.0

## True while the jetpack is equipped (Shift toggles). Weapons are blocked
## while flying — GameManager checks this before allowing a shot.
var jetpack_on: bool = false

var jetpack_fuel: float = 5.0
var _jetpacking: bool = false
var _jet_flame_t: float = 0.0

## Set by GameManager — which player owns this worm (0-based).
var player_id: int = 0

## Set by GameManager — color that identifies this worm's owner.
var player_color: Color = Color("4a90d9")

@export var is_active: bool = false:
	set(value):
		is_active = value
		queue_redraw()

## Set by GameManager every frame for the active worm — world-space angle
## (radians) from the worm toward the mouse cursor. Drives the bazooka sprite.
var aim_angle: float = 0.0

const BAZOOKA_TEXTURE: Texture2D = preload("res://Assets/bazooka.png")

## Sprite of the currently selected weapon and how far back along the aim
## direction its grip sits. Both set by GameManager on weapon switch.
var weapon_texture: Texture2D = BAZOOKA_TEXTURE
var weapon_grip: float = -8.0

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
	jetpack_fuel = jetpack_max_fuel


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
		if kc == KEY_SHIFT:
			_toggle_jetpack()
		elif not jetpack_on and (kc == KEY_SPACE or kc == KEY_W or kc == KEY_UP):
			_jump_queued = true


func _toggle_jetpack() -> void:
	if jetpack_on:
		jetpack_on = false
	elif jetpack_fuel > 0.0:
		jetpack_on = true
		_jump_queued = false


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	var dir: float = 0.0
	if is_active and not input_locked:
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			dir -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			dir += 1.0

	# Jetpack flight: directional thrust, gravity still pulls. Fuel burns only
	# while a thrust key is held. Walking and jumping are disabled while worn.
	_jetpacking = false
	if jetpack_on and is_active and not input_locked:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			velocity.y = maxf(velocity.y - jetpack_thrust * delta, -jetpack_max_rise_speed)
			_jetpacking = true
		if dir != 0.0:
			velocity.x = clampf(velocity.x + dir * jetpack_lateral_thrust * delta,
					-jetpack_max_lateral_speed, jetpack_max_lateral_speed)
			_jetpacking = true
		else:
			# Gentle air drag so the worm doesn't drift forever.
			velocity.x = move_toward(velocity.x, 0.0, jetpack_lateral_thrust * 0.25 * delta)

		if _jetpacking:
			jetpack_fuel = maxf(0.0, jetpack_fuel - delta)
			_jet_flame_t += delta * 30.0
			if jetpack_fuel <= 0.0:
				jetpack_on = false
	else:
		if _jump_queued and is_on_floor():
			velocity.y = jump_velocity

		if dir != 0.0:
			velocity.x = dir * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
	_jump_queued = false

	# Capture pre-slide state: move_and_slide() zeroes velocity.y on landing.
	var was_airborne: bool = not is_on_floor()
	var impact_speed: float = velocity.y

	move_and_slide()

	if was_airborne and is_on_floor():
		var excess: float = impact_speed - fall_damage_min_speed
		if excess > 0.0 and take_damage(excess * fall_damage_scale):
			kill()
			return

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

	# Weapon stays holstered while the jetpack is worn (Worms-style: no
	# shooting mid-flight).
	if not jetpack_on:
		_draw_weapon()
	_draw_jetpack()

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


## Thrust flame under the worm while flying, plus a fuel gauge below the body
## once any fuel has been spent this turn.
func _draw_jetpack() -> void:
	if _jetpacking:
		var flame_len: float = 10.0 + 4.0 * sin(_jet_flame_t)
		var base_y: float = radius - 1.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(-4.0, base_y),
			Vector2(4.0, base_y),
			Vector2(0.0, base_y + flame_len),
		]), Color(1.0, 0.62, 0.1, 0.9))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-2.0, base_y),
			Vector2(2.0, base_y),
			Vector2(0.0, base_y + flame_len * 0.55),
		]), Color(1.0, 0.9, 0.4, 0.95))

	if jetpack_fuel >= jetpack_max_fuel:
		return

	const BAR_W: float = 24.0
	const BAR_H: float = 3.0
	var top_left := Vector2(-BAR_W * 0.5, radius + 5.0)
	var frac: float = clampf(jetpack_fuel / jetpack_max_fuel, 0.0, 1.0)
	draw_rect(Rect2(top_left, Vector2(BAR_W, BAR_H)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(top_left, Vector2(BAR_W * frac, BAR_H)), Color(0.35, 0.75, 1.0))
	draw_rect(Rect2(top_left, Vector2(BAR_W, BAR_H)), Color(0, 0, 0, 0.5), false, 1.0)


## Current weapon resting on the worm, rotated toward the aim point.
## Mirrored vertically when aiming left so the top side stays up.
func _draw_weapon() -> void:
	if weapon_texture == null:
		return
	var flip: bool = absf(wrapf(aim_angle, -PI, PI)) > PI * 0.5
	draw_set_transform(Vector2.ZERO, aim_angle, Vector2(1.0, -1.0 if flip else 1.0))
	draw_texture(weapon_texture,
			Vector2(weapon_grip, -weapon_texture.get_height() * 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
