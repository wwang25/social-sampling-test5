extends Control

# Emitted when this card is clicked: that card is the choice.
# Times are Time.get_ticks_msec() values. With a click, press and choice happen at the same moment.
signal chosen(card: Control, press_ms: int, choose_ms: int)
# Kept so main.gd's connection still works. Emitted once with 1.0 when the card is chosen.
signal drag_progress(card: Control, progress: float)

@onready var image: TextureRect = $VBox/Image
@onready var label: RichTextLabel = $VBox/Label

# Set by main.gd: where the chosen card settles after the click.
var choice_position := Vector2(200, 300)
var rest_position := Vector2.ZERO
var enabled := false
var tween: Tween
var base_scale := 1.0

#const BASE_SIZE := Vector2(320, 560)   # card size at scale 1.0 (main.gd reads this)
#const BASE_CONTENT := 288.0            # image width/height and label width at scale 1.0
#var base_font_size := 22
#var base_bold_font_size := 20

const BORDER_COLOR := Color(0.1, 0.4, 0.9)  # blue
const BORDER_WIDTH := 4

func _ready() -> void:
	# Fixed layout, so large picture files cannot stretch the card.
	set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	size = Vector2(320, 560)
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(288, 288)
	label.custom_minimum_size.x = 288
	rest_position = position
	pivot_offset = size / 2.0  # scale around the card centre
	label.bbcode_enabled = true
	label.add_theme_color_override("default_color", Color.BLACK)
	label.add_theme_color_override("bold_color", Color.BLACK)  # for the [b] text
	_add_border()
	if name == "LeftCard":
		_debug_tree(self, 0)  # TEMPORARY: remove once the gray is found


# TEMPORARY: prints every node in the card with its type and anything that could paint grey.
func _debug_tree(node: Node, depth: int) -> void:
	var info := "%s%s (%s)" % ["  ".repeat(depth), node.name, node.get_class()]
	if node is CanvasItem:
		info += " modulate=%s self_modulate=%s" % [node.modulate, node.self_modulate]
	if node is ColorRect:
		info += " COLOR=%s" % node.color
	if node is Control:
		for style_name in ["panel", "normal", "background"]:
			if node.has_theme_stylebox_override(style_name):
				var sb = node.get_theme_stylebox(style_name)
				info += " override[%s]=%s" % [style_name, sb.bg_color if sb is StyleBoxFlat else sb.get_class()]
	if node is TextureRect and node.texture:
		info += " texture=%s" % node.texture.resource_path
	print(info)
	for child in node.get_children():
		_debug_tree(child, depth + 1)


func _add_border() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE        # white card face
	style.border_color = BORDER_COLOR
	style.set_border_width_all(BORDER_WIDTH)
	style.set_corner_radius_all(12)
	# If the card node itself is a Panel/PanelContainer, its default grey style
	# is the grey you see, so replace it with the white bordered style.
	# Use the Panel already in the scene (otherwise its default grey style covers ours).
	var frame: Panel = get_node_or_null("Panel") as Panel
	if frame == null:
		frame = Panel.new()
		add_child(frame)
	frame.add_theme_stylebox_override("panel", style)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE  # clicks still reach the card
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	move_child(frame, 0)                # draw behind the image and text

	# Make sure nothing inside the card paints its own grey background.
	var clear := StyleBoxEmpty.new()
	label.add_theme_stylebox_override("normal", clear)
	label.add_theme_stylebox_override("focus", clear)
	var vbox := $VBox
	if vbox is PanelContainer or vbox is Panel:
		vbox.add_theme_stylebox_override("panel", clear)
	image.self_modulate = Color.WHITE
	image.modulate = Color.WHITE
	self_modulate = Color.WHITE


func set_items(text: String) -> void:
	label.text = text

func _load_image(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	push_warning("Missing image: " + path)
	return null


func show_option(text: String, image_path: String) -> void:
	if tween:
		tween.kill()
	label.text = text
	image.texture = _load_image(image_path)
	position = rest_position
	rotation = 0.0
	scale = Vector2.ONE * base_scale
	modulate.a = 1.0
	z_index = 0
	visible = true
	enabled = true


# Called by main.gd on the card that was NOT chosen: it disappears and cannot be clicked.
func dismiss() -> void:
	enabled = false
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)


# Called by main.gd to fade the chosen card away at the end of a trial.
func fade_out() -> void:
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)


# A left click on this card chooses it.
func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		_choose()


func _choose() -> void:
	enabled = false
	z_index = 1  # draw the chosen card above the other one
	var now := Time.get_ticks_msec()
	# Emit first so the reaction time is not delayed by the animation.
	chosen.emit(self, now, now)
	drag_progress.emit(self, 1.0)
	# Settle in the middle and grow slightly so the choice stands out.
	if tween:
		tween.kill()
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", choice_position, 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * base_scale * 1.1, 0.15)


# Called by main.gd whenever the screen size changes.
func set_layout(pos: Vector2, new_scale: float) -> void:
	base_scale = new_scale
	rest_position = pos
	if enabled:
		position = pos
		scale = Vector2.ONE * base_scale
