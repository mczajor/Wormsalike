@tool
extends Node2D

@export var terrain_noise := FastNoiseLite.new()
@export var map_width:  int   = 1500
@export var map_height: int   = 1000
@export var cell_size:  int   = 7

@export var noise_frequency: float = 0.01
@export var octaves:         int   = 4
@export var lacunarity:      float = 2.0
@export var gain:            float = 0.55

@export var threshold_top:    float = 0.15
@export var threshold_bottom: float = 0.7
@export var edge_falloff: float = 0.3


@export var ground_color:  Color = Color("5a3e28")
@export var outline_color: Color = Color("3a2510")
@export var outline_width: float = 3.0

#Spawn points 
@export var max_slope_angle: float = 50.0   
@export var spawn_offset:    float = 14.0  
@export var spawn_spacing:   float = 6.0 


var _grid_width:  int
var _grid_height: int
var _grid: PackedFloat32Array
var spawn_points: Array[Vector2] = []


func _ready() -> void:
	generate()

func generate(_seed: int = 0) -> void:
	if _seed == 0:
		_seed = randi()
	for child in get_children():
		child.queue_free()
	set_terrain_noise(_seed)
	spawn_points.clear()
	_build_grid()
	_fill_enclosed_caves()
	_build_polygons()

func set_terrain_noise(_seed: int):
	terrain_noise.seed               = _seed
	terrain_noise.frequency          = noise_frequency
	terrain_noise.fractal_type       = FastNoiseLite.FRACTAL_FBM
	terrain_noise.fractal_octaves    = octaves
	terrain_noise.fractal_lacunarity = lacunarity
	terrain_noise.fractal_gain       = gain
	

# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 1 – fill float grid with signed noise values
# ═══════════════════════════════════════════════════════════════════════════════

func _build_grid() -> void:
	_grid_width  = map_width  + 2
	_grid_height = map_height + 2

	_grid = PackedFloat32Array()
	_grid.resize(_grid_width * _grid_height)

	for i in _grid.size():
		_grid[i] = -1.0

	for y in map_height:
		var t: float = float(y) / float(map_height - 1)
		var height_threshold: float = lerp(threshold_bottom, threshold_top, t)
		for x in map_width:
			var fx: float = float(x) / float(map_width - 1)
			var falloff: float = pow(2.0 * fx - 1.0, 2.0) * edge_falloff
			var n: float = (terrain_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			_grid[(y + 1) * _grid_width + (x + 1)] = n - height_threshold - falloff * 1.2

# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 1.5 – fill enclosed caves so the grid matches what gets rendered
# ═══════════════════════════════════════════════════════════════════════════════
#
# Marching squares paints odd-depth (enclosed) loops as solid ground, but the
# grid still holds them as empty (<= 0). That mismatch let worms spawn inside
# "caves" that look solid and have no collision boundary. We reconcile it here:
# flood-fill empty space inward from the map border, then mark any empty cell
# the flood never reached as solid. After this pass, every empty cell is
# reachable from outside, so no enclosed pockets remain.

func _fill_enclosed_caves() -> void:
	var total: int = _grid_width * _grid_height
	# reachable[i] == true  ->  this empty cell connects to the outside border.
	var reachable := PackedByteArray()
	reachable.resize(total)

	var stack: Array[int] = []

	# Seed the flood from every border cell that is currently empty.
	for ix in _grid_width:
		_seed_if_empty(ix, 0,                stack, reachable)
		_seed_if_empty(ix, _grid_height - 1, stack, reachable)
	for iy in _grid_height:
		_seed_if_empty(0,               iy, stack, reachable)
		_seed_if_empty(_grid_width - 1, iy, stack, reachable)

	# 4-directional flood fill across empty cells.
	while not stack.is_empty():
		var idx: int = stack.pop_back()
		var x: int = idx % _grid_width
		var y: int = idx / _grid_width

		if x > 0:
			_seed_if_empty(x - 1, y, stack, reachable)
		if x < _grid_width - 1:
			_seed_if_empty(x + 1, y, stack, reachable)
		if y > 0:
			_seed_if_empty(x, y - 1, stack, reachable)
		if y < _grid_height - 1:
			_seed_if_empty(x, y + 1, stack, reachable)

	# Any empty cell the flood never reached is an enclosed cave -> make it solid.
	# Use a small positive value so marching squares treats it as ground.
	for i in total:
		if _grid[i] <= 0.0 and reachable[i] == 0:
			_grid[i] = 1.0


# Helper: if the cell at (x, y) is empty and not yet visited, mark it reachable
# and push it onto the flood-fill stack.
func _seed_if_empty(x: int, y: int, stack: Array[int], reachable: PackedByteArray) -> void:
	var idx: int = y * _grid_width + x
	if reachable[idx] == 1:
		return
	if _grid[idx] > 0.0:
		return   # solid cell, flood can't pass through
	reachable[idx] = 1
	stack.append(idx)


# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 2 – Marching Squares with interpolated edge crossings
# ═══════════════════════════════════════════════════════════════════════════════

func _build_polygons() -> void:
	var segments: Array = []

	var interpolate := func(a: float, b: float) -> float:
		if absf(a - b) < 0.00001:
			return 0.5
		return clampf(a / (a - b), 0.0, 1.0)

	# In _build_polygons — loop bounds
	for y in range(_grid_height - 1):
		for x in range(_grid_width - 1):
			var v0: float = _grid[y       * _grid_width + x    ]
			var v1: float = _grid[y       * _grid_width + x + 1]
			var v2: float = _grid[(y + 1) * _grid_width + x + 1]
			var v3: float = _grid[(y + 1) * _grid_width + x    ]

			var c0: int = 1 if v0 > 0.0 else 0
			var c1: int = 1 if v1 > 0.0 else 0
			var c2: int = 1 if v2 > 0.0 else 0
			var c3: int = 1 if v3 > 0.0 else 0

			var case_idx: int = c0 | (c1 << 1) | (c2 << 2) | (c3 << 3)
			#print(case_idx, "    ", _grid[y       * map_width + x    ])
			
			if case_idx == 0 or case_idx == 15:
				continue
		
			var top    := Vector2(x + interpolate.call(v0, v1), y                  			)
			var right  := Vector2(x + 1,               			y + interpolate.call(v1, v2))
			var bottom := Vector2(x + interpolate.call(v3, v2), y + 1              			)
			var left   := Vector2(x,                   			y + interpolate.call(v0, v3))
			
			match case_idx:
				1:  segments.append([top,    left  ])
				2:  segments.append([right,  top   ])
				3:  segments.append([right,  left  ])
				4:  segments.append([bottom, right ])
				5:
					segments.append([top,    left  ])
					segments.append([bottom, right ])
				6:  segments.append([bottom, top   ])
				7:  segments.append([bottom, left  ])
				8:  segments.append([left,   bottom])
				9:  segments.append([top,    bottom])
				10:
					segments.append([right,  top   ])
					segments.append([left,   bottom])
				11: segments.append([right,  bottom])
				12: segments.append([left,   right ])
				13: segments.append([top,    right ])
				14: segments.append([left,   top   ])
				
	var loops := _assemble_loops(segments)

	var pixel_loops: Array = []
	for loop in loops:
		if loop.size() >= 3:
			var pts := PackedVector2Array()
			for pt in loop:
				pts.append(Vector2(pt.x * cell_size, pt.y * cell_size))
			pixel_loops.append(pts)

	if pixel_loops.is_empty():
		return

	#checks for caves, if depth is odd then it's a cave
	var depths: Array = []
	depths.resize(pixel_loops.size())
	for i in pixel_loops.size():
		var depth := 0
		var probe: Vector2 = pixel_loops[i][0]
		for j in pixel_loops.size():
			if i != j and Geometry2D.is_point_in_polygon(probe, pixel_loops[j]):
				depth += 1
		depths[i] = depth

	for i in pixel_loops.size():
		#implementing caves was too much work so I just skip them, maybe I'll get around to it at some point
		if depths[i] % 2 != 0:
			continue
		_spawn_polygon(pixel_loops[i])
	_collect_spawn_points(pixel_loops)


# ── Segment → loop assembler ──────────────────────────────────────────────────

func _assemble_loops(segments: Array) -> Array:
	if segments.is_empty():
		return []

	var adj: Dictionary = {}
	var _get_keys := func(pt: Vector2) -> String:
		return "%d_%d" % [roundi(pt.x * 10000), roundi(pt.y * 10000)]
	
	#segments is a list of sets of points, we create a dictionary that uses the points as keys to later check for loop closing
	var _add := func(pt: Vector2, seg_idx: int) -> void:
		var key: String = _get_keys.call(pt)
		if not adj.has(key):
			adj[key] = []
		adj[key].append(seg_idx)
	#each segment consists of at lest two points that form a line in marching squares algorithm
	for i in segments.size():
		_add.call(segments[i][0], i)
		_add.call(segments[i][1], i)

	var used := PackedByteArray()
	used.resize(segments.size())
	var loops: Array = []

	for start_seg in segments.size():
		if used[start_seg] == 1:
			continue

		var loop: Array = []
		var current_pt: Vector2 = segments[start_seg][0]
		var current_seg: int    = start_seg
		used[current_seg] = 1

		while true:
			var next_pt: Vector2 = segments[current_seg][1] \
				if current_pt.is_equal_approx(segments[current_seg][0]) \
				else segments[current_seg][0]
			loop.append(next_pt)

			var key: String = _get_keys.call(next_pt)
			var found: bool = false
			if adj.has(key):
				for seg_idx in adj[key]:
					if used[seg_idx] == 0:
						used[seg_idx] = 1
						current_pt    = next_pt
						current_seg   = seg_idx
						found         = true
						break
			if not found:
				break

		if loop.size() >= 3:
			loops.append(loop)

	return loops
				
# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 3 – spawn a Polygon2D node
# ═══════════════════════════════════════════════════════════════════════════════

func _spawn_polygon(points: PackedVector2Array) -> void:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color   = ground_color

	if outline_width > 0.0:
		var line := Line2D.new()
		var closed_pts := PackedVector2Array(points)
		closed_pts.append(points[0])
		line.points        = closed_pts
		line.width         = outline_width
		line.default_color = outline_color
		line.joint_mode    = Line2D.LINE_JOINT_ROUND
		line.end_cap_mode  = Line2D.LINE_CAP_ROUND
		poly.add_child(line)

	var body     := StaticBody2D.new()
	var col_poly := CollisionPolygon2D.new()
	col_poly.polygon = points
	body.add_child(col_poly)
	poly.add_child(body)

	add_child(poly)
	if Engine.is_editor_hint():
		poly.owner = get_tree().edited_scene_root
		
		
# ═══════════════════════════════════════════════════════════════════════════════
#  DESTRUCTION – carve a circle into the grid and rebuild polygons
# ═══════════════════════════════════════════════════════════════════════════════

func explode_at(world_pos: Vector2, radius: float) -> void:
	if _grid.is_empty():
		return

	var local_pos: Vector2 = to_local(world_pos)
	var gx: float = local_pos.x / float(cell_size)
	var gy: float = local_pos.y / float(cell_size)
	var gr: float = radius / float(cell_size)

	# _grid is indexed with a +1 offset relative to world cells (see _build_grid).
	var cx: float = gx + 1.0
	var cy: float = gy + 1.0

	var min_ix: int = maxi(0, int(cx - gr - 1.0))
	var max_ix: int = mini(_grid_width - 1, int(cx + gr + 1.0))
	var min_iy: int = maxi(0, int(cy - gr - 1.0))
	var max_iy: int = mini(_grid_height - 1, int(cy + gr + 1.0))

	var gr2: float = gr * gr
	for iy in range(min_iy, max_iy + 1):
		for ix in range(min_ix, max_ix + 1):
			var dx: float = float(ix) - cx
			var dy: float = float(iy) - cy
			if dx * dx + dy * dy < gr2:
				_grid[iy * _grid_width + ix] = -1.0

	_rebuild_terrain()


func _rebuild_terrain() -> void:
	for child in get_children():
		child.queue_free()
	spawn_points.clear()
	_fill_enclosed_caves()
	_build_polygons()
	queue_redraw()


# ═══════════════════════════════════════════════════════════════════════════════
#  STEP 4 – check for viable spawn points
# ═══════════════════════════════════════════════════════════════════════════════

func _collect_spawn_points(pixel_loops: Array) -> void:
	var cos_threshold: float = cos(deg_to_rad(max_slope_angle))

	for loop in pixel_loops:
		var count: int = loop.size()
		for i in count:
			var a: Vector2 = loop[i]
			var b: Vector2 = loop[(i + 1) % count]

			var edge_dir: Vector2 = (b - a).normalized()
			if absf(edge_dir.x) < cos_threshold:
				continue

			var mid: Vector2 = (a + b) * 0.5
			var grid_mid: Vector2 = mid / cell_size


			var perp_a := Vector2(-edge_dir.y,  edge_dir.x)
			var perp_b := Vector2( edge_dir.y, -edge_dir.x)
			var up_perp := perp_a if perp_a.y < 0.0 else perp_b
			var down_perp := perp_b if perp_a.y < 0.0 else perp_a


			var sample_up   := grid_mid + up_perp
			var sample_down := grid_mid + down_perp

			var gx_up   := clampi(roundi(sample_up.x)   + 1, 0, _grid_width  - 1)
			var gy_up   := clampi(roundi(sample_up.y)   + 1, 0, _grid_height - 1)
			var gx_down := clampi(roundi(sample_down.x) + 1, 0, _grid_width  - 1)
			var gy_down := clampi(roundi(sample_down.y) + 1, 0, _grid_height - 1)

			# Floor = air above, solid below
			if _grid[gy_up   * _grid_width + gx_up]   > 0.0:
				continue
			if _grid[gy_down * _grid_width + gx_down] <= 0.0:
				continue

			var spawn_pos: Vector2 = mid + Vector2(0.0, -spawn_offset)

			var too_close := false
			for existing in spawn_points:
				if spawn_pos.distance_to(existing) < spawn_spacing:
					too_close = true
					break
			if not too_close:
				spawn_points.append(spawn_pos)
