extends SceneTree

const BODY:    Color = Color8(178, 182, 190)
const BODY_LT: Color = Color8(216, 220, 226)
const BODY_DK: Color = Color8(130, 134, 144)
const RED:     Color = Color8(214, 69, 56)
const RED_DK:  Color = Color8(164, 47, 39)
const DARK:    Color = Color8(58, 60, 68)
const GLASS:   Color = Color8(140, 200, 230)
const OLIVE:    Color = Color8(96, 110, 62)
const OLIVE_LT: Color = Color8(130, 146, 86)
const OLIVE_DK: Color = Color8(64, 74, 42)
const GRN:    Color = Color8(74, 134, 62)
const GRN_LT: Color = Color8(124, 182, 104)
const GRN_DK: Color = Color8(44, 84, 38)
const GUN_LT: Color = Color8(112, 114, 124)


func _init() -> void:
	_gen_rocket().save_png("res://Assets/rocket.png")
	_gen_bazooka().save_png("res://Assets/bazooka.png")
	_gen_grenade().save_png("res://Assets/grenade.png")
	print("weapon sprites written to res://Assets/")
	quit()


func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			img.set_pixel(x, y, c)


func _gen_rocket() -> Image:
	var img := Image.create_empty(24, 10, false, Image.FORMAT_RGBA8)

	_rect(img, 3, 2, 16, 7, BODY)
	_rect(img, 3, 2, 16, 2, BODY_LT)
	_rect(img, 3, 6, 16, 7, BODY_DK)

	for x in range(17, 24):
		var t: float = float(x - 17) / 6.0
		var half: float = lerpf(3.0, 0.7, t)
		for y in range(2, 8):
			if absf(float(y) + 0.5 - 5.0) <= half:
				img.set_pixel(x, y, RED if y < 5 else RED_DK)

	_rect(img, 0, 3, 2, 6, DARK)

	for p: Vector2i in [Vector2i(3, 0), Vector2i(3, 1), Vector2i(4, 0),
			Vector2i(4, 1), Vector2i(5, 1)]:
		img.set_pixel(p.x, p.y, RED)
		img.set_pixel(p.x, 9 - p.y, RED_DK)

	_rect(img, 12, 3, 13, 4, GLASS)
	return img


func _gen_bazooka() -> Image:
	var img := Image.create_empty(28, 10, false, Image.FORMAT_RGBA8)

	_rect(img, 0, 2, 27, 7, OLIVE)
	_rect(img, 0, 2, 27, 2, OLIVE_LT)
	_rect(img, 0, 6, 27, 7, OLIVE_DK)

	_rect(img, 0, 2, 1, 7, DARK)
	_rect(img, 26, 2, 27, 7, DARK)

	_rect(img, 5, 2, 6, 7, RED)

	_rect(img, 17, 0, 19, 1, DARK)
	_rect(img, 11, 8, 13, 9, DARK)
	return img


func _gen_grenade() -> Image:
	var img := Image.create_empty(10, 10, false, Image.FORMAT_RGBA8)

	var center := Vector2(4.5, 5.5)
	for y in range(2, 10):
		for x in range(0, 10):
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d > 4.0:
				continue
			var c: Color = GRN
			if d > 3.2:
				c = GRN_DK
			elif x <= 3 and y <= 4:
				c = GRN_LT
			img.set_pixel(x, y, c)

	_rect(img, 3, 0, 5, 1, DARK)
	img.set_pixel(6, 0, GUN_LT)
	return img
