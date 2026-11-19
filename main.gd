extends Control

const PROMPT := "Which health behaviour is more common among Australian teens?"
const INTER_TRIAL_SEC := 0.6
const REPEATS := 1 # how many times each pair appears
const RANDOMISE_SIDES := true # randomly swap which option appears on the left
const IMAGE_DIR := "res://images/"
const IMAGE_EXT := ".jpg"
const CARD_GAP := 20.0        # space between the two cards
const MAX_CARD_SCALE := 1.6   # stops cards becoming huge on big desktop screens
const TOP_MARGIN := 200.0   # keeps the cards clear of the prompt text
# >>>>>>>>>> CHANGED: progress bar thickness (new constant) <<<<<<<<<<
const PROGRESS_BAR_HEIGHT := 25.0  # thickness of the progress bar in pixels

# 15 items, listed once. the item with the higher value is scored as correct. 
const ITEMS := [
	{"name": "Walking or riding a bike, skateboard, scooter, or rollerblades to [b]get to places[/b]", "image": "res://images/health1.jpg", "value": 15},
	{"name": "[b]NOT USUALLY[/b] consuming sugar sweetened drinks (e.g., soft drinks, fruit drinks, cordials, energy drinks)", "image": "res://images/health2.jpg", "value": 14},
	{"name": "[b]Maintaining[/b] a healthy weight", "image": "res://images/health3.jpg", "value": 13},
	{"name": "[b]NOT USUALLY[/b] eating fast food [b]every week[/b]", "image": "res://images/health4.jpg", "value": 12},
	{"name": "Eating at least [b]2 servings[/b] of [b]FRUIT per day[/b]", "image": "res://images/health5.jpg", "value": 11},
	{"name": "Sleeping between 8 and 10 hours per night on [b]WEEK DAYS[/b]", "image": "res://images/health6.jpg", "value": 10},
	{"name": "Sleeping between 8 and 10 hours per night on [b]WEEKENDS[/b]", "image": "res://images/health7.jpg", "value": 9},
	{"name": "Participating in organised [b]sport OUTSIDE of school[/b] at least [b]3 times a week[/b]", "image": "res://images/health8.jpg", "value": 8},
	{"name": "Drinking at least [b]2 litres[/b] of [b]WATER per day[/b]", "image": "res://images/health9.jpg", "value": 7},
	{"name": "Taking around [b]10,000 STEPS per day[/b]", "image": "res://images/health10.jpg", "value": 6},
	{"name": "[b]Staying OFF[/b] screen-based devices [b]before bed[/b]", "image": "res://images/health11.jpg", "value": 5},
	{"name": "[b]Volunteering[/b] for an organisation", "image": "res://images/health12.jpg", "value": 4},
	{"name": "Being physically [b]active[/b] for at least [b]1 hour each day[/b]", "image": "res://images/health13.jpg", "value": 3},
	{"name": "Spending [b]NO MORE than 2 hours per day[/b] on screens [b]OUTSIDE[/b] of school work", "image": "res://images/health14.jpg", "value": 2},
	{"name": "Eating at least [b]5 servings[/b] of [b]VEGETABLES per day[/b]", "image": "res://images/health15.jpg", "value": 1},
]


func build_trials() -> Array:
	var list: Array = []
	for i in REPEATS:
		for x in ITEMS.size():
			for y in range(x + 1, ITEMS.size()):  # every pair exactly once
				var a: Dictionary = ITEMS[x]
				var b: Dictionary = ITEMS[y]
				var swap := RANDOMISE_SIDES and randf() < 0.5
				var left: Dictionary = b if swap else a
				var right: Dictionary = a if swap else b

				var correct := ""
				if a.has("value") and b.has("value") and a["value"] != b["value"]:
					correct = a["name"] if a["value"] > b["value"] else b["name"]

				list.append({
					"id": "%d-%d" % [x + 1, y + 1],
					"left": left["name"],
					"right": right["name"],
					"left_image": left["image"],
					"right_image": right["image"],
					"correct": correct,
				})
	list.shuffle()
	return list

var participant_id := "P001"
var trials: Array = []
var trial_index := -1
var stimulus_onset_ms := 0
var results: Array = []

# "health behaviour rank 1 " -> res://images/health1.jpg
func image_path(option_text: String) -> String:
	return IMAGE_DIR + option_text.to_lower().replace(" ", "_") + IMAGE_EXT




@onready var left_card = $LeftCard
@onready var right_card = $RightCard
@onready var prompt_label: Label = $PromptLabel
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var start_panel: Control = $StartPanel
@onready var end_panel: Control = $EndPanel
@onready var end_label: Label = $EndPanel/EndLabel
@onready var start_button: Button = $StartPanel/VBox/StartButton



func _ready() -> void:
	# Plain white task background, drawn behind everything else.
	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)
	RenderingServer.set_default_clear_color(Color.WHITE)

	# Start and end screens: white instead of the default grey panel style.
	var white_style := StyleBoxFlat.new()
	white_style.bg_color = Color.WHITE
	if start_panel is Panel or start_panel is PanelContainer:
		start_panel.add_theme_stylebox_override("panel", white_style)
	if end_panel is Panel or end_panel is PanelContainer:
		end_panel.add_theme_stylebox_override("panel", white_style)

	left_card.visible = false
	right_card.visible = false
	end_panel.visible = false
	prompt_label.text = PROMPT
	prompt_label.visible = false
	left_card.chosen.connect(_on_card_chosen)
	right_card.chosen.connect(_on_card_chosen)
	left_card.drag_progress.connect(_on_drag_progress)
	right_card.drag_progress.connect(_on_drag_progress)
	resized.connect(_layout)  # re-centre when the window changes or the device rotates
	_layout()
	start_button.pressed.connect(_start_task)
	# >>>>>>>>>> CHANGED: start button blue background, black text <<<<<<<<<<
	var blue := Color(0.55, 0.75, 1.00)
	var blue_hover := Color(0.66, 0.82, 1.00)    
	var blue_pressed := Color(0.42, 0.65, 0.95)
	var state_colours := {
		"normal": blue, "focus": blue, "disabled": blue,
		"hover": blue_hover, "pressed": blue_pressed,
	}
	for state in state_colours:
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = state_colours[state]
		btn_style.border_color = Color(0.20, 0.45, 0.80)
		btn_style.set_border_width_all(3) 
		btn_style.set_corner_radius_all(8)
		start_button.add_theme_stylebox_override(state, btn_style)
	for colour_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		start_button.add_theme_color_override(colour_name, Color.BLACK)

	progress_bar.custom_minimum_size.y = PROGRESS_BAR_HEIGHT
	progress_bar.offset_bottom = progress_bar.offset_top + PROGRESS_BAR_HEIGHT
	progress_bar.max_value = 105
	progress_bar.min_value = 0
	progress_bar.value = -1
	prompt_label.add_theme_color_override("font_color", Color.BLACK)
	end_label.add_theme_color_override("font_color", Color.BLACK)
	



# Sizes and centres the two cards to suit the current screen.
func _layout() -> void:
	var card_size: Vector2 = left_card.size
	var pair_width := card_size.x * 2.0 + CARD_GAP

	# Scale so the pair uses up to 94% of the width and 55% of the height.
	var s := minf(size.x * 0.94 / pair_width, size.y * 0.55 / card_size.y)
	s = minf(s, MAX_CARD_SCALE)

	# Cards scale around their centre, so place them by their centres.
	var centre := size / 2.0 + Vector2(0, 40)  # slightly low, leaving room for the prompt
	var half_gap := (card_size.x + CARD_GAP) * s / 2.0
	left_card.set_layout(centre - Vector2(half_gap, 0) - card_size / 2.0, s)
	right_card.set_layout(centre + Vector2(half_gap, 0) - card_size / 2.0, s)

	# Dragging a card to the centre chooses it.
	var middle := centre - card_size / 2.0
	left_card.choice_position = middle
	right_card.choice_position = middle


func _start_task() -> void:
	start_panel.visible = false
	prompt_label.visible = true
	trials = build_trials()
	trial_index = -1
	results.clear()
	_next_trial()


func _next_trial() -> void:
	trial_index += 1
	if trial_index >= trials.size():
		_finish()
		return
	var trial: Dictionary = trials[trial_index]
	#progress_label.text = "%d / %d" % [trial_index + 1, trials.size()]
	progress_bar.value = trial_index
	left_card.show_option(trial["left"], trial["left_image"])
	right_card.show_option(trial["right"], trial["right_image"])
	stimulus_onset_ms = Time.get_ticks_msec()


# Fades the other card as the dragged card nears the middle (progress 0 to 1).
func _on_drag_progress(card: Control, progress: float) -> void:
	var other: Control = right_card if card == left_card else left_card
	other.modulate.a = 1.0 - progress


# Runs when a card is dragged into the middle: that card is the choice.
func _on_card_chosen(chosen_card, press_ms: int, choose_ms: int) -> void:
	var trial: Dictionary = trials[trial_index]
	var chose_left: bool = chosen_card == left_card
	var other_card = right_card if chose_left else left_card
	var chosen: String = trial["left"] if chose_left else trial["right"]
	var rejected: String = trial["right"] if chose_left else trial["left"]

	# The other card disappears and is locked so it cannot also be dragged.
	other_card.dismiss()

	var accuracy := ""
	if trial["correct"] != "":
		accuracy = "1" if chosen == trial["correct"] else "0"

	results.append({
		"participant": participant_id,
		"trial": trial_index + 1,
		"pair_id": trial["id"],
		"left_option": trial["left"],
		"right_option": trial["right"],
		"chosen_side": "left" if chose_left else "right",
		"rejected": rejected,
		"chosen": chosen,
		"correct": accuracy,
		"press_rt_ms": press_ms - stimulus_onset_ms,
		"rt_ms": choose_ms - stimulus_onset_ms,
	})

	# The chosen option stays in the middle for INTER_TRIAL_SEC, then fades.
	await get_tree().create_timer(INTER_TRIAL_SEC).timeout
	chosen_card.fade_out()
	await get_tree().create_timer(0.25).timeout
	_next_trial()


const CSV_COLUMNS := ["participant", "trial", "pair_id", "left_option", "right_option", "chosen_side", "rejected", "chosen", "correct", "press_rt_ms", "rt_ms"]



func _finish() -> void:
	left_card.visible = false
	right_card.visible = false
	prompt_label.visible = false
	#progress_label.text = ""
	var where := _save_results()
	if OS.is_debug_build() and where != "":
		end_label.text += "\nSaved: " + where
	end_panel.visible = true


func _csv_escape(s: String) -> String:
	if s.contains(",") or s.contains("\"") or s.contains("\n"):
		return "\"" + s.replace("\"", "\"\"") + "\""
	return s


func _csv_text() -> String:
	var lines: PackedStringArray = []
	lines.append(",".join(CSV_COLUMNS))
	for r in results:
		var cells: PackedStringArray = []
		for col in CSV_COLUMNS:
			cells.append(_csv_escape(str(r[col])))
		lines.append(",".join(cells))
	return "\n".join(lines) + "\n"


func _save_results() -> String:
	var csv := _csv_text()
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var file_name := "results_%s_%s.csv" % [participant_id, stamp]

	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(csv.to_utf8_buffer(), file_name, "text/csv")
		return "downloaded by the browser"

	var path := "user://" + file_name
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Could not write %s (error %d)" % [path, FileAccess.get_open_error()])
		return ""
	f.store_string(csv)
	f.close()
	return ProjectSettings.globalize_path(path)
