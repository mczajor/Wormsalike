extends Node2D

## Top-level game controller.
##   - Spawns worms at the generator's reported spawn points.
##   - Left-click = explosion at the mouse position (carves terrain, knocks worms).
##   - Tab       = cycle which worm accepts input.

@export var explosion_radius: float = 40.0
@export var knockback_strength: float = 600.0
@export var num_worms: int = 4

const WormScene: PackedScene = preload("res://Scenes/worm.tscn")

@onready var _generator: Node2D = $Map/Generator
@onready var _camera: Camera2D = $Camera

var _worms: Array[CharacterBody2D] = []


func _ready() -> void:
	# Generator._ready() runs before this (children first), so spawn_points exist.
	_spawn_worms()
	_frame_camera_on_map()
	get_viewport().size_changed.connect(_frame_camera_on_map)


func _frame_camera_on_map() -> void:
	# Fit the whole map grid inside the viewport, centered.
	var g: Node2D = _generator
	var map_w: float = float(g.map_width) * float(g.cell_size)
	var map_h: float = float(g.map_height) * float(g.cell_size)
	var center_local: Vector2 = Vector2(map_w * 0.5, map_h * 0.5)

	var viewport_size: Vector2 = get_viewport_rect().size
	var padding: float = 1.02  # tiny margin so the map edge isn't kissing the screen edge
	var zoom_x: float = viewport_size.x / (map_w * padding)
	var zoom_y: float = viewport_size.y / (map_h * padding)
	var z: float = minf(zoom_x, zoom_y)

	_camera.global_position = g.to_global(center_local)
	_camera.zoom = Vector2(z, z)


func _spawn_worms() -> void:
	var pts: Array[Vector2] = _generator.spawn_points.duplicate()
	pts.shuffle()
	var n: int = mini(num_worms, pts.size())
	for i in n:
		var w: CharacterBody2D = WormScene.instantiate()
		add_child(w)
		# Spawn a bit above the reported point so the worm falls onto the surface
		# rather than starting clipped into it.
		w.global_position = _generator.to_global(pts[i] + Vector2(0.0, -12.0))
		w.is_active = (i == 0)
		_worms.append(w)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_explode_at_mouse()

	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB:
			_cycle_active_worm()
		elif event.physical_keycode == KEY_F11:
			_toggle_fullscreen()
		elif event.physical_keycode == KEY_ESCAPE:
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _toggle_fullscreen() -> void:
	var mode: int = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _explode_at_mouse() -> void:
	var world_pos: Vector2 = get_global_mouse_position()
	_generator.explode_at(world_pos, explosion_radius)

	# Apply knockback to worms within twice the blast radius.
	var reach: float = explosion_radius * 2.0
	for w in _worms:
		if not is_instance_valid(w):
			continue
		var offset: Vector2 = w.global_position - world_pos
		var d: float = offset.length()
		if d >= reach:
			continue
		var dir: Vector2 = offset.normalized() if d > 0.01 else Vector2.UP
		var falloff: float = 1.0 - (d / reach)
		w.velocity += dir * knockback_strength * falloff


func _cycle_active_worm() -> void:
	if _worms.is_empty():
		return
	var active_idx: int = -1
	for i in _worms.size():
		if _worms[i].is_active:
			active_idx = i
			break
	if active_idx != -1:
		_worms[active_idx].is_active = false
	var next: int = ((active_idx + 1) % _worms.size()) if active_idx != -1 else 0
	_worms[next].is_active = true
