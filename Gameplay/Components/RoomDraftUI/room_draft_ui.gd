extends Control

@onready var option_buttons = [$OptionsContainer/Option1/Button, $OptionsContainer/Option2/Button, $OptionsContainer/Option3/Button]

var player: Player = null
var current_options: Array[RoomData] = []
var selected_index: int = 0

const SELECTED_COLOR = Color("80f0a0")

func _ready():
	visible = false
	DungeonManager.connect("draft_options_ready", _on_draft_options_ready)
	DungeonManager.connect("placement_ended", _on_draft_cancelled)

	# Connect signals for direct button clicks to allow mouse interaction
	option_buttons[0].pressed.connect(_on_option_selected.bind(0))
	option_buttons[1].pressed.connect(_on_option_selected.bind(1))
	option_buttons[2].pressed.connect(_on_option_selected.bind(2))

func _process(_delta):
	if visible:
		var screen_size = get_viewport().get_visible_rect().size
		var screen_center = screen_size / 2.0
		self.global_position = screen_center - Vector2(size.x / 2.0, 100)

func _unhandled_input(event: InputEvent):
	if not visible:
		return

	if event.is_action_pressed("LEFT"):
		selected_index = maxi(0, selected_index - 1)
		_update_selection_visuals()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("RIGHT"):
		selected_index = mini(current_options.size() - 1, selected_index + 1)
		_update_selection_visuals()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("UP"):
		# This now correctly handles confirmation from keyboard or gamepad
		_confirm_selection()
		get_viewport().set_input_as_handled()

func _on_draft_options_ready(options: Array[RoomData]):
	player = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(player):
		printerr("RoomDraftUI: Could not find player!")
		return

	current_options = options
	selected_index = 0

	for i in range(option_buttons.size()):
		if i < options.size():
			var room_data: RoomData = options[i]
			option_buttons[i].get_parent().visible = true
			option_buttons[i].text = room_data.resource_path.get_file().trim_suffix(".tres")
		else:
			option_buttons[i].get_parent().visible = false

	visible = true
	_update_selection_visuals()

func _update_selection_visuals():
	for i in range(option_buttons.size()):
		if i == selected_index:
			option_buttons[i].modulate = SELECTED_COLOR
		else:
			option_buttons[i].modulate = Color.WHITE

	if selected_index < current_options.size():
		DungeonManager.update_draft_preview(current_options[selected_index])

# New handler for processing direct mouse clicks on buttons
func _on_option_selected(index: int):
	selected_index = index
	_confirm_selection()

# Renamed and repurposed function to confirm the currently selected option
func _confirm_selection():
	if selected_index >= current_options.size():
		return

	var chosen_room_data: RoomData = current_options[selected_index]
	DungeonManager.confirm_draft_choice(chosen_room_data)

	visible = false

func _on_draft_cancelled():
	visible = false
	current_options.clear()
