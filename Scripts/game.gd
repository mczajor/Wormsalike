extends Node2D

## Top-level game controller.
##   - Spawns worms and assigns them to players in round-robin order.
##   - Tab   = cycle active worm within the current player's team.
##   - Esc   = end current player's turn, pass control to the next player.
##   - LMB   = explosion at mouse position (carves terrain, knocks worms).

@export var explosion_radius:  float = 40.0
@export var knockback_strength: float = 600.0

## Damage dealt to each worm caught in an explosion.
@export var shot_damage: float = 25.0

## Background fill color shown behind the terrain (fallback if no texture).
@export var background_color: Color = Color("87ceeb")

## Sky texture, stretched to fill the whole camera view.
@export var sky_texture: Texture2D = preload("res://Assets/sky.png")

## Lava texture for the kill plane, tiled (repeated) rather than stretched.
@export var lava_texture: Texture2D = preload("res://Assets/lava.png")

## Kill-plane appearance.
@export var kill_plane_color: Color = Color(0.85, 0.1, 0.1, 0.45)

## Fraction of map height (from the top) where the plane starts. Higher value
## = lower starting position. 0.98 keeps it near the bottom but on-screen.
@export var kill_plane_start_frac: float = 0.98

## How far up (world pixels) the plane rises each time it rises.
@export var kill_plane_rise: float = 35.0

## Number of full rounds (cycles through all players) between each rise.
@export var rounds_per_rise: int = 3

## The rising kill-plane node.
var _kill_plane: KillPlane

## Counts completed turns. Used to trigger a kill-plane rise once per full round.
var _turns_taken: int = 0

## Total worms to spawn. Distributed evenly across players in round-robin order.
## e.g. 6 worms + 2 players → 3 worms each; 6 worms + 4 players → 2 worms each (closest even split).
@export var num_worms: int = 9

## How many players are playing (2-4 supported).
@export_range(2, 4) var num_players: int = 3

## One distinct color per player for their worms' highlight ring.
const PLAYER_COLORS: Array[Color] = [
	Color("4a90d9"),  # Player 1 – blue
	Color("e05c5c"),  # Player 2 – red
	Color("4caf50"),  # Player 3 – green
	Color("f0c040"),  # Player 4 – yellow
]

const WormScene: PackedScene = preload("res://Scenes/worm.tscn")
const HudScene:        PackedScene = preload("res://Scenes/hud.tscn")
const ExplosionEffect: GDScript    = preload("res://Scripts/explosion_effect.gd")

@onready var _generator: Node2D = $Map/Generator
@onready var _camera:    Camera2D = $Camera

var _hud: CanvasLayer

## _players[i] is the Array[Worm] belonging to player i.
var _players: Array = []

## Index into _players — whose turn it is.
var _current_player: int = 0

## Index into _players[_current_player] — which of that player's worms is selected.
var _current_worm: int = 0

## Endpoints for the aim line, updated every frame. Both are Vector2.ZERO
## when there is no active shooter (nothing is drawn).
var _aim_start: Vector2 = Vector2.ZERO
var _aim_end:   Vector2 = Vector2.ZERO

## Set true once a player has won. Freezes turn/shoot input.
var _game_over: bool = false

## True after the current player has fired their single shot.
## Blocks further shooting and character switching until the next turn.
var _has_shot: bool = false

## True from the moment a turn-end is triggered until the next turn begins.
## Prevents the turn being ended twice (e.g. post-shot timer + worm death).
var _turn_ending: bool = false

## Seconds to wait after a shot before control passes, so the explosion
## and any resulting knockback/falls can resolve first. The shooter's input
## is locked during this window.
@export var post_shot_delay: float = 0.5


func _ready() -> void:
	_hud = HudScene.instantiate()
	add_child(_hud)
	_hud.quit_confirmed.connect(_on_quit_confirmed)
	_hud.quit_cancelled.connect(_on_quit_cancelled)

	_build_environment()

	_frame_camera_on_map()
	get_viewport().size_changed.connect(_frame_camera_on_map)

	await _spawn_worms()
	print("=== Game Start — Player %d's turn ===" % (_current_player + 1))


## Creates the sky background behind everything and the rising kill plane.
func _build_environment() -> void:
	var g: Node2D = _generator
	var map_w: float = float(g.map_width)  * float(g.cell_size)
	var map_h: float = float(g.map_height) * float(g.cell_size)

	# Sky: a screen-space layer that always fills the whole camera view,
	# regardless of camera position or zoom. Stretched to fit.
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -100   # behind the world
	add_child(sky_layer)

	var sky := TextureRect.new()
	sky.texture = sky_texture
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE   # stretch to fill
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fallback color shows through if the texture is missing.
	if sky_texture == null:
		var bg := ColorRect.new()
		bg.color = background_color
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		sky_layer.add_child(bg)
	else:
		sky_layer.add_child(sky)

	# Kill plane: start it inside the visible map so it's actually on screen.
	var start_y: float = g.to_global(Vector2(0.0, map_h * kill_plane_start_frac)).y
	var left_x:  float = g.to_global(Vector2(0.0, 0.0)).x - map_w
	var width:   float = map_w * 3.0

	_kill_plane = KillPlane.new()
	_kill_plane.plane_color    = kill_plane_color
	_kill_plane.texture        = lava_texture
	_kill_plane.rise_per_round = kill_plane_rise
	_kill_plane.z_index        = -50   # in front of sky, behind terrain
	add_child(_kill_plane)
	_kill_plane.setup(start_y, left_x, width, map_h * 2.0)


# ---------------------------------------------------------------------------
# Aim line
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _game_over or _hud.is_pause_menu_open():
		_aim_start = Vector2.ZERO
		_aim_end   = Vector2.ZERO
		queue_redraw()
		return
	var team: Array = _players[_current_player] if not _players.is_empty() else []
	if team.is_empty():
		_aim_start = Vector2.ZERO
		_aim_end   = Vector2.ZERO
		queue_redraw()
		return

	var shooter: Worm = team[_current_worm]
	var origin: Vector2    = shooter.global_position
	var mouse: Vector2     = get_global_mouse_position()
	var direction: Vector2 = (mouse - origin).normalized()

	# Extend the ray far enough to always reach the map edge.
	var map_diagonal: float = Vector2(
		float(_generator.map_width) * float(_generator.cell_size),
		float(_generator.map_height) * float(_generator.cell_size)
	).length()
	var far_point: Vector2 = origin + direction * map_diagonal

	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(origin, far_point)
	query.exclude = [shooter.get_rid()]
	var hit := space.intersect_ray(query)

	_aim_start = origin
	_aim_end   = hit.position if not hit.is_empty() else far_point
	queue_redraw()


func _draw() -> void:
	if _aim_start == Vector2.ZERO and _aim_end == Vector2.ZERO:
		return
	draw_line(_aim_start, _aim_end, Color(1, 1, 1, 0.55), 1.0)
	# Small dot at the impact point so it's clear where the shot lands.
	draw_circle(_aim_end, 2.5, Color(1, 1, 1, 0.8))


# ---------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------

func _frame_camera_on_map() -> void:
	var g: Node2D = _generator
	var map_w: float = float(g.map_width) * float(g.cell_size)
	var map_h: float = float(g.map_height) * float(g.cell_size)
	var viewport_size: Vector2 = get_viewport_rect().size
	var padding: float = 1.02
	var z: float = minf(viewport_size.x / (map_w * padding),
						viewport_size.y / (map_h * padding))
	_camera.global_position = g.to_global(Vector2(map_w * 0.5, map_h * 0.5))
	_camera.zoom = Vector2(z, z)


# ---------------------------------------------------------------------------
# Spawning
# ---------------------------------------------------------------------------

func _spawn_worms() -> void:
	# Build empty team arrays.
	for i in num_players:
		_players.append([])

	var pts: Array[Vector2] = _generator.spawn_points.duplicate()
	pts.shuffle()
	var n: int = mini(num_worms, pts.size())
	# Track which points have been used so retries don't reuse them.
	var used_indices: Array[int] = []

	for i in n:
		var player_idx: int = i % num_players

		var w: Worm = WormScene.instantiate()
		w.player_id    = player_idx
		w.player_color = PLAYER_COLORS[player_idx]
		w.is_active    = false
		add_child(w)
		w.global_position = _generator.to_global(pts[i])
		w.kill_plane = _kill_plane
		w.died.connect(_on_worm_died)
		used_indices.append(i)
		_players[player_idx].append(w)

		# One physics frame later, check if the worm spawned inside terrain.
		# If so, relocate it to the next unused spawn point.
		var worm_ref := w
		var pts_ref  := pts
		var used_ref := used_indices
		await get_tree().physics_frame
		if not is_instance_valid(worm_ref):
			continue
		if worm_ref.get_slide_collision_count() > 0 or worm_ref.is_on_floor():
			# Find the next unused point and teleport there.
			var relocated := false
			for j in pts_ref.size():
				if used_ref.has(j):
					continue
				worm_ref.global_position = _generator.to_global(pts_ref[j])
				used_ref.append(j)
				relocated = true
				print("[SPAWN] worm %d relocated to point %d" % [i, j])
				break
			if not relocated:
				print("[SPAWN] worm %d: no free point found, keeping current position" % i)

	# Activate the first worm of the first player.
	_activate_current_worm()
	_refresh_hud()


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Once the game is over, the only accepted input is ESC to quit.
	if _game_over:
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			get_tree().quit()
		return

	# While the pause menu is open, ESC closes it; all other input is ignored
	# (the menu's buttons handle Yes/No themselves).
	if _hud.is_pause_menu_open():
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			_on_quit_cancelled()
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_shoot()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_explode_at(get_global_mouse_position())
		return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.physical_keycode:
		KEY_TAB:
			_cycle_worm_within_player()
		KEY_ESCAPE:
			_open_pause_menu()
		KEY_F11:
			_toggle_fullscreen()


## Open the confirmation menu and freeze the active worm's movement.
func _open_pause_menu() -> void:
	_hud.show_pause_menu()
	var team: Array = _players[_current_player]
	if not team.is_empty() and _current_worm < team.size():
		(team[_current_worm] as Worm).input_locked = true


func _on_quit_confirmed() -> void:
	get_tree().quit()


func _on_quit_cancelled() -> void:
	_hud.hide_pause_menu()
	# Resume play. Only unfreeze the worm if it wasn't already locked by a shot.
	if _has_shot:
		return
	var team: Array = _players[_current_player]
	if not team.is_empty() and _current_worm < team.size():
		(team[_current_worm] as Worm).input_locked = false


func _toggle_fullscreen() -> void:
	var mode: int = DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		else DisplayServer.WINDOW_MODE_FULLSCREEN
	)


# ---------------------------------------------------------------------------
# Turn management
# ---------------------------------------------------------------------------

## Deactivate the current worm, move to the next worm in this player's team.
func _cycle_worm_within_player() -> void:
	if _has_shot:
		return   # locked out after shooting
	var team: Array = _players[_current_player]
	if team.size() <= 1:
		return   # nothing to cycle through

	_deactivate_current_worm()
	_current_worm = (_current_worm + 1) % team.size()
	_activate_current_worm()


## End this player's turn and hand control to the next player.
func _end_turn() -> void:
	if _turn_ending:
		return
	_turn_ending = true
	_deactivate_current_worm()

	# Count this completed turn; rise the kill plane every N full rounds.
	_turns_taken += 1
	var turns_per_rise: int = num_players * maxi(1, rounds_per_rise)
	if _turns_taken % turns_per_rise == 0 and _kill_plane != null:
		_kill_plane.rise()

	# Advance to the next player, skipping any with no worms left.
	var checked: int = 0
	while checked < num_players:
		_current_player = (_current_player + 1) % num_players
		checked += 1
		if not _players[_current_player].is_empty():
			break

	# Each new turn starts on worm index 0 for that player's current team.
	_current_worm = 0
	_has_shot = false
	_turn_ending = false

	# Clear any leftover input lock from the previous shot.
	for team in _players:
		for w: Worm in team:
			w.input_locked = false

	_activate_current_worm()
	_refresh_hud()

	print("=== Player %d's turn ===" % (_current_player + 1))


## Wait for the explosion to settle, then pass control to the next player.
func _end_turn_after_shot() -> void:
	await get_tree().create_timer(post_shot_delay).timeout
	# The game may have ended (someone won) while we were waiting.
	if _game_over:
		return
	_end_turn()


func _activate_current_worm() -> void:
	var team: Array = _players[_current_player]
	if team.is_empty():
		return
	(team[_current_worm] as Worm).is_active = true


func _deactivate_current_worm() -> void:
	var team: Array = _players[_current_player]
	if team.is_empty():
		return
	if _current_worm < 0 or _current_worm >= team.size():
		return
	(team[_current_worm] as Worm).is_active = false


func _on_worm_died(worm: Worm) -> void:
	var was_active: bool = worm.is_active

	# Remove from its player's team array.
	for team in _players:
		var idx: int = team.find(worm)
		if idx != -1:
			team.remove_at(idx)
			break

	worm.queue_free()
	_refresh_hud()

	# Check for a winner: exactly one player with worms remaining.
	if _check_for_winner():
		return

	# If the dead worm was the active one, pick the next or end the turn.
	if was_active:
		var team: Array = _players[_current_player]
		if team.is_empty():
			_end_turn()
		else:
			_current_worm = clampi(_current_worm, 0, team.size() - 1)
			_activate_current_worm()


## Returns true and ends the game if only one player has worms left.
func _check_for_winner() -> bool:
	var alive_players: Array[int] = []
	for i in _players.size():
		if not _players[i].is_empty():
			alive_players.append(i)

	if alive_players.size() > 1:
		return false

	_game_over = true
	_deactivate_current_worm()

	if alive_players.size() == 1:
		var winner: int = alive_players[0]
		_hud.show_winner(winner, PLAYER_COLORS[winner])
		print("=== Player %d won the game ===" % (winner + 1))
	else:
		# Edge case: last two worms died together — no survivors.
		print("=== Draw — no players remaining ===")

	return true


func _refresh_hud() -> void:
	_hud.refresh(_players, PLAYER_COLORS, _current_player)


func _spawn_explosion_effect(world_pos: Vector2) -> void:
	var effect := Node2D.new()
	effect.set_script(ExplosionEffect)
	add_child(effect)
	effect.global_position = world_pos
	effect.init(explosion_radius * 2.0)


# ---------------------------------------------------------------------------
# Explosions
# ---------------------------------------------------------------------------

func _shoot() -> void:
	if _has_shot:
		return   # one shot per turn
	var team: Array = _players[_current_player]
	if team.is_empty():
		return
	var shooter: Worm = team[_current_worm]

	var origin: Vector2    = shooter.global_position
	var mouse: Vector2     = get_global_mouse_position()
	var direction: Vector2 = (mouse - origin).normalized()

	var map_diagonal: float = Vector2(
		float(_generator.map_width) * float(_generator.cell_size),
		float(_generator.map_height) * float(_generator.cell_size)
	).length()
	var far_point: Vector2 = origin + direction * map_diagonal

	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(origin, far_point)
	query.exclude = [shooter.get_rid()]
	var hit := space.intersect_ray(query)

	var explosion_pos: Vector2 = hit.position if not hit.is_empty() else far_point
	_explode_at(explosion_pos)

	# Lock the turn: no more shooting, switching, or movement.
	_has_shot = true
	shooter.input_locked = true
	_end_turn_after_shot()


func _explode_at(world_pos: Vector2) -> void:
	_generator.explode_at(world_pos, explosion_radius)
	_spawn_explosion_effect(world_pos)

	var reach: float = explosion_radius * 2.0
	var killed: Array[Worm] = []
	for team in _players:
		for w: Worm in team:
			if not is_instance_valid(w):
				continue
			var offset: Vector2 = w.global_position - world_pos
			var d: float = offset.length()
			if d >= reach:
				continue
			var dir: Vector2 = offset.normalized() if d > 0.01 else Vector2.UP
			var falloff: float = 1.0 - (d / reach)
			w.velocity += dir * knockback_strength * falloff
			# Damage scales linearly with proximity: full shot_damage at the
			# blast center, falling to 0 at the edge of reach.
			if w.take_damage(shot_damage * falloff):
				killed.append(w)

	# Process deaths AFTER the loop so we don't mutate the team arrays mid-iteration.
	for w in killed:
		if is_instance_valid(w):
			w.kill()
