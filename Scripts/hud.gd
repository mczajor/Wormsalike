extends CanvasLayer

## HUD — shows each player's remaining worm count.
##
## Call [method refresh] whenever the player list changes
## (after spawning, after a worm dies, after a turn change).

const _ICON_SIZE:    float = 10.0   # radius of each worm dot icon
const _ICON_SPACING: float = 26.0   # horizontal gap between icons
const _PANEL_PAD:    float = 10.0   # inner padding inside each card
const _CARD_GAP:     float = 8.0    # gap between player cards

## Container that holds one card per player.
@onready var _cards: HBoxContainer = $Margin/Cards

## Emitted by the pause menu buttons.
signal quit_confirmed
signal quit_cancelled

## The pause-menu overlay, built on demand. Null when not showing.
var _pause_menu: Control = null


func is_pause_menu_open() -> bool:
	return _pause_menu != null


func refresh(players: Array, player_colors: Array[Color], current_player: int) -> void:
	# Clear old cards.
	for child in _cards.get_children():
		child.queue_free()

	for i in players.size():
		var team: Array = players[i]
		var color: Color = player_colors[i]
		var is_active: bool = (i == current_player)
		_cards.add_child(_build_card(i, team, color, is_active))


## Display a centered victory banner in the winning player's color.
func show_winner(player_idx: int, color: Color) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.border_color = color
	style.border_width_left   = 3
	style.border_width_right  = 3
	style.border_width_top    = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left   = 32
	style.content_margin_right  = 32
	style.content_margin_top    = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var label := Label.new()
	label.text = "Player %d won the game!" % (player_idx + 1)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var hint := Label.new()
	hint.text = "Press ESC to quit"
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	hint.add_theme_font_size_override("font_size", 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)


## Show the "End the game?" confirmation overlay. Does nothing if already open.
func show_pause_menu() -> void:
	if _pause_menu != null:
		return

	# Full-screen dimmer that also catches clicks behind the menu.
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_pause_menu = overlay

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 0.98)
	style.border_color = Color(1, 1, 1, 0.25)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left   = 28
	style.content_margin_right  = 28
	style.content_margin_top    = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var label := Label.new()
	label.text = "End the game?"
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons)

	var yes_btn := Button.new()
	yes_btn.text = "Yes"
	yes_btn.custom_minimum_size = Vector2(90, 36)
	yes_btn.pressed.connect(func(): quit_confirmed.emit())
	buttons.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(90, 36)
	no_btn.pressed.connect(func(): quit_cancelled.emit())
	buttons.add_child(no_btn)

	no_btn.grab_focus()   # default to the safe choice


## Remove the pause menu overlay if it's showing.
func hide_pause_menu() -> void:
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null


func _build_card(player_idx: int, team: Array, color: Color, is_active: bool) -> PanelContainer:
	var panel := PanelContainer.new()

	# Style — slightly highlighted border when it's this player's turn.
	var style := StyleBoxFlat.new()
	style.bg_color         = Color(0, 0, 0, 0.55)
	style.border_color     = color if is_active else Color(1, 1, 1, 0.15)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left   = 8
	style.content_margin_right  = 8
	style.content_margin_top    = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Player label.
	var label := Label.new()
	label.text = "P%d" % (player_idx + 1)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(label)

	# Row of worm dot icons.
	var icon_row := HBoxContainer.new()
	icon_row.add_theme_constant_override("separation", 4)
	vbox.add_child(icon_row)

	for w in team:
		var dot := _WormDot.new(color)
		icon_row.add_child(dot)

	return panel


# ---------------------------------------------------------------------------
# Inner class — a tiny Control that draws a single worm-dot icon.
# ---------------------------------------------------------------------------
class _WormDot extends Control:
	var _color: Color

	func _init(c: Color) -> void:
		_color = c
		custom_minimum_size = Vector2(14, 14)

	func _draw() -> void:
		var center := Vector2(7, 7)
		draw_circle(center, 5.0, _color)
		draw_arc(center, 5.0, 0.0, TAU, 24, Color(0, 0, 0, 0.4), 1.0)
