extends Node2D

@export_group("Movement")
@export var speed: float = 300.0
@export var window_size: Vector2 = Vector2(200, 200)

@export_group("Cursor")
@export var detection_radius: float = 180.0

@export_group("Petting")
@export var max_affection: float = 100.0
@export var affection_gain: float = 15.0
@export var petting_delay: float = 0.4
@export var drag_threshold: float = 12.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area: Area2D = $Area2D
@onready var heart_label: Label = $HeartLabel

var direction = Vector2(1, 0)
var screen_size = Vector2.ZERO

var is_idling = false
var idle_timer = 0.0
var is_curious = false

enum Interaction {
	NONE,
	PENDING,
	PETTING,
	DRAGGING
}

var interaction = Interaction.NONE
var press_position = Vector2.ZERO
var drag_offset = Vector2.ZERO
var hold_timer = 0.0

var affection = 0.0

var heart_timer = 0.0
var heart_duration = 0.7
var heart_start_position = Vector2.ZERO


func _ready() -> void:
	screen_size = Vector2(
		DisplayServer.screen_get_size()
	)

	animated_sprite.play("Walking")

	heart_label.visible = false
	heart_start_position = heart_label.position

	area.input_event.connect(_on_area_input)


func _physics_process(delta: float) -> void:
	var mouse_pos = Vector2(
		DisplayServer.mouse_get_position()
	)

	var window_pos = Vector2(
		DisplayServer.window_get_position()
	)

	update_heart(delta)
	update_interaction(delta, mouse_pos)

	
	if interaction == Interaction.DRAGGING:
		var new_pos = mouse_pos - drag_offset
		DisplayServer.window_set_position(
			Vector2i(new_pos)
		)
		return

	
	if interaction != Interaction.NONE:
		animated_sprite.play("Idle")
		return
		
		
	var dog_pos = window_pos + animated_sprite.position
	var distance = mouse_pos.distance_to(dog_pos)

	if distance < detection_radius:
		if not is_curious:
			is_curious = true
			is_idling = false
			animated_sprite.play("Idle")

		animated_sprite.flip_h = mouse_pos.x < dog_pos.x
		return

	if is_curious:
		is_curious = false
		animated_sprite.play("Walking")

	if is_idling:
		idle_timer -= delta

		if idle_timer > 0:
			animated_sprite.play("Idle")
			return

		is_idling = false
		animated_sprite.play("Walking")

	animated_sprite.play("Walking")

	window_pos += direction * speed * delta

	var max_x = max(
		0.0,
		screen_size.x - window_size.x
	)

	var max_y = max(
		0.0,
		screen_size.y - window_size.y
	)

	window_pos.x = clamp(
		window_pos.x, 0.0, max_x
	)

	window_pos.y = clamp(
		window_pos.y, 0.0, max_y
	)

	DisplayServer.window_set_position(
		Vector2i(window_pos)
	)

	if window_pos.x <= 0 or window_pos.x >= max_x:
		direction.x *= -1
		animated_sprite.flip_h = direction.x < 0
		maybe_idle()

	if window_pos.y <= 0 or window_pos.y >= max_y:
		direction.y *= -1
		maybe_idle()

func _on_area_input(
	_viewport,
	event,
	_shape_idx
) -> void:

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:

			if event.pressed:
				interaction = Interaction.PENDING

				press_position = Vector2(
					DisplayServer.mouse_get_position()
				)

				var win_pos = Vector2(
					DisplayServer.window_get_position()
				)

				drag_offset = press_position - win_pos
				hold_timer = 0.0

			else:
				stop_interaction()


func update_interaction(
	delta: float,
	mouse_pos: Vector2
) -> void:

	if interaction == Interaction.NONE:
		return

	if not Input.is_mouse_button_pressed(
		MOUSE_BUTTON_LEFT
	):
		stop_interaction()
		return

	if interaction == Interaction.PENDING:
		hold_timer += delta

		var moved = mouse_pos.distance_to(
			press_position
		)

		if moved >= drag_threshold:
			interaction = Interaction.DRAGGING
			return

		if hold_timer >= petting_delay:
			interaction = Interaction.PETTING
			print("Petting started!")

	elif interaction == Interaction.PETTING:
		if mouse_pos.distance_to(
			press_position
		) >= drag_threshold:
			stop_interaction()
			return

		affection = min(
			affection + affection_gain * delta,
			max_affection
		)

		show_heart()


func stop_interaction() -> void:
	if interaction == Interaction.PETTING:
		print("Affection: ", int(affection))

	interaction = Interaction.NONE
	hold_timer = 0.0

func show_heart() -> void:
	if heart_timer > 0.0:
		return

	heart_timer = heart_duration
	heart_label.visible = true
	heart_label.position = heart_start_position
	heart_label.modulate.a = 1.0


func update_heart(delta: float) -> void:
	if heart_timer <= 0.0:
		return

	heart_timer = max(0.0, heart_timer - delta)

	var progress = 1.0 - (
		heart_timer / heart_duration
	)

	heart_label.position = (
		heart_start_position
		+ Vector2(0, -25 * progress)
	)

	heart_label.modulate.a = 1.0 - progress

	if heart_timer <= 0.0:
		heart_label.visible = false

func maybe_idle() -> void:
	if randf() < 0.3:
		is_idling = true
		idle_timer = randf_range(1.0, 3.0)
		animated_sprite.play("Idle")
