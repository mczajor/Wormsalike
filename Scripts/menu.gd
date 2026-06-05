extends Control

## Main menu — pick the number of teams and worms per team, then start.

const GAME_SCENE: String = "res://Scenes/game.tscn"

const MIN_TEAMS: int = 2
const MAX_TEAMS: int = 4
const MIN_WORMS: int = 1
const MAX_WORMS: int = 8

var _teams_value: Label
var _worms_value: Label


func _ready() -> void:
	var sky := TextureRect.new()
	sky.texture = preload("res://Assets/sky.png")
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.65)
	style.border_color = Color(1, 1, 1, 0.25)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left     = 10
	style.corner_radius_top_right    = 10
	style.corner_radius_bottom_left  = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left   = 40
	style.content_margin_right  = 40
	style.content_margin_top    = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "WORMSALIKE"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_teams_value = _add_counter_row(vbox, "Teams",
			GameConfig.num_players, _on_teams_changed)
	_worms_value = _add_counter_row(vbox, "Worms per team",
			GameConfig.worms_per_team, _on_worms_changed)

	var start_btn := Button.new()
	start_btn.text = "Start"
	start_btn.custom_minimum_size = Vector2(0, 44)
	start_btn.add_theme_font_size_override("font_size", 20)
	start_btn.pressed.connect(_start_game)
	vbox.add_child(start_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(0, 36)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	vbox.add_child(quit_btn)

	start_btn.grab_focus()


## One settings row: "<name>     [-]  <value>  [+]". Returns the value label.
func _add_counter_row(parent: Container, label_text: String,
		initial: int, on_change: Callable) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(36, 36)
	row.add_child(minus)

	var value_label := Label.new()
	value_label.text = str(initial)
	value_label.add_theme_font_size_override("font_size", 20)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size = Vector2(32, 0)
	row.add_child(value_label)

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(36, 36)
	row.add_child(plus)

	minus.pressed.connect(func() -> void: on_change.call(-1))
	plus.pressed.connect(func() -> void: on_change.call(1))
	return value_label


func _on_teams_changed(delta: int) -> void:
	GameConfig.num_players = clampi(GameConfig.num_players + delta, MIN_TEAMS, MAX_TEAMS)
	_teams_value.text = str(GameConfig.num_players)


func _on_worms_changed(delta: int) -> void:
	GameConfig.worms_per_team = clampi(GameConfig.worms_per_team + delta, MIN_WORMS, MAX_WORMS)
	_worms_value.text = str(GameConfig.worms_per_team)


func _start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
