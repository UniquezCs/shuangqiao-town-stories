extends CharacterBody2D

const SPEED := 120.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	sprite.texture = _make_pixel_player_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0

	velocity = direction.normalized() * SPEED
	move_and_slide()


func _make_pixel_player_texture() -> ImageTexture:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	var hair := Color("#33222a")
	var skin := Color("#f0b287")
	var shirt := Color("#2f7dd1")
	var pants := Color("#29345c")
	var boots := Color("#1c1b22")

	_fill_rect(image, Rect2i(5, 1, 6, 3), hair)
	_fill_rect(image, Rect2i(4, 4, 8, 4), skin)
	image.set_pixel(6, 5, Color("#252030"))
	image.set_pixel(9, 5, Color("#252030"))
	_fill_rect(image, Rect2i(5, 8, 6, 4), shirt)
	_fill_rect(image, Rect2i(4, 12, 3, 3), pants)
	_fill_rect(image, Rect2i(9, 12, 3, 3), pants)
	_fill_rect(image, Rect2i(3, 15, 4, 1), boots)
	_fill_rect(image, Rect2i(9, 15, 4, 1), boots)

	return ImageTexture.create_from_image(image)


func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			image.set_pixel(x, y, color)
