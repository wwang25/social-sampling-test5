extends Control


# direction: -1 = left option chosen, 1 = right option chosen.
# Times are Time.get_ticks_msec() values.
signal swiped(direction: int, press_ms: int, release_ms: int)

const SWIPE_THRESHOLD := 180.0 # drag distance (px) that counts as a choice
const MAX_TILT_DEG := 12.0
const FLY_DISTANCE := 1400.0
const DIM_ALPHA := 0.35 # how faded the unchosen option gets

@onready var prompt_label: Label = $PromptLabel
@onready var left_box: Control = $LeftBox
@onready var right_box: Control = $RightBox
@onready var left_option: Label = $LeftBox/LeftOption
@onready var right_option: Label = $RightBox/RightOption
@onready var left_image: TextureRect = $LeftBox/LeftImage
@onready var right_image: TextureRect = $RightBox/RightImage

func _load_image(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	push_warning("Missing image: " + path)
	return null


var rest_position := Vector2.ZERO
var enabled := false
var dragging := false
var drag_start_x := 0.0
var press_ms := 0
var tween: Tween

func _ready() -> void:
	rest_position = position
	pivot_offset = size/2.0 # rotate around the card centre
	
func set_prompt(text: String) -> void:
	prompt_label.text = text
	
	
func show_options(left: String, right: String, left_path: String, right_path: String) -> void:
	left_option.text = left
	right_option.text = right
	left_image.texture = _load_image(left_path)
	right_image.texture = _load_image(right_path)
	position = rest_position
	rotation = 0.0
	modulate.a = 1.0
	left_box.modulate.a = 1.0
	right_box.modulate.a = 1.0
	enabled = true
	
	
# Press: start a drag only if the press lands on the card
func _gui_input(event: InputEvent) -> void:
	print("gui_input: ", event, " enabled=", enabled)
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if tween:
			tween.kill()
		dragging = true
		drag_start_x = get_global_mouse_position().x
		press_ms = Time.get_ticks_msec()
		accept_event()
			
			
# Move and release: listen globally so the drag continues if the finger leaves the card.
func _input(event: InputEvent) -> void:
	if not dragging:
		return
	if event is InputEventMouseMotion:
		_update_drag(get_global_mouse_position().x - drag_start_x)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.is_pressed():
		dragging = false
		var dx := get_global_mouse_position().x - drag_start_x
		if absf(dx) >= SWIPE_THRESHOLD:
			_commit(signf(dx))
		else:
			_snap_back()
			

# Dragging right favours the right option, so the left one fades, and vice versa.
func _update_drag(dx: float) -> void:
	position.x = rest_position.x + dx
	var t  := clampf(dx / SWIPE_THRESHOLD, -1.0, 1.0)
	rotation_degrees = t * MAX_TILT_DEG
	left_box.modulate.a = lerpf(1.0, DIM_ALPHA, maxf(t, 0.0))
	right_box.modulate.a = lerpf(1.0, DIM_ALPHA, maxf(-t, 0.0))
	
	
func _commit(dir: float) -> void:
	enabled = false
	# Emit first so the reaction time is not delayed by the exit animation.
	swiped.emit(int(dir), press_ms, Time.get_ticks_msec())
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:x", rest_position.x + dir * FLY_DISTANCE, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	
	
func _snap_back() -> void:
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", rest_position, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", 0.0, 0.2)
	tween.tween_property(left_box, "modulate:a", 1.0, 0.2)
	tween.tween_property(right_box, "modulate:a", 1.0, 0.2)
	
