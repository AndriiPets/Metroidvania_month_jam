extends Control

@onready var option_buttons = [$OptionsContainer/Option1/Button, $OptionsContainer/Option2/Button, $OptionsContainer/Option3/Button]

# --- NEW VARIABLES ---
var player: Player = null
var current_options: Array[RoomData] = []
var selected_index: int = 0

# The color to tint the selected button
const SELECTED_COLOR = Color("80f0a0") # A light green

func _ready():
	visible = false
	DungeonManager.connect("draft_options_ready", _on_draft_options_ready)
	# Use placement_ended to hide the UI if drafting is cancelled
	DungeonManager.connect("placement_ended", _on_draft_cancelled)

func _process(_delta):
	# If the UI is visible, we want to keep it positioned above the center of the screen.
	# Since the camera is following the player, the player is always at the screen's center.
	if visible:
		# Get the size of the visible game window (the viewport).
		var screen_size = get_viewport().get_visible_rect().size

		# Calculate the center point of that window.
		var screen_center = screen_size / 2.0

		# Position the UI's top-left corner relative to the center.
		# We shift it left by half its own width to center it horizontally,
		# and shift it up by a fixed amount (e.g., 100 pixels) to place it above the player.
		self.global_position = screen_center - Vector2(size.x / 2.0, 100)

func _unhandled_input(event: InputEvent):
	# Only process input if the UI is active
	if not visible:
		return

	if event.is_action_pressed("LEFT"):
		selected_index = maxi(0, selected_index - 1)
		_update_selection_visuals()
		DungeonManager.update_room_preview(current_options[selected_index])
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("RIGHT"):
		selected_index = mini(current_options.size() - 1, selected_index + 1)
		_update_selection_visuals()
		DungeonManager.update_room_preview(current_options[selected_index])
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("SHOOT"):
		_on_option_button_pressed()
		get_viewport().set_input_as_handled()

func _on_draft_options_ready(options: Array[RoomData], _exit_data):
	# Find the player node
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
			option_buttons[i].text = room_data.resource_path.get_file().trim_suffix(".tres") # Show filename as text
		else:
			option_buttons[i].get_parent().visible = false

	visible = true
	_update_selection_visuals()

	if not current_options.is_empty():
		DungeonManager.update_room_preview(current_options[0])

func _update_selection_visuals():
	for i in range(option_buttons.size()):
		if i == selected_index:
			option_buttons[i].modulate = SELECTED_COLOR
		else:
			option_buttons[i].modulate = Color.WHITE

func _on_option_button_pressed():
	if selected_index >= current_options.size():
		return

	#var chosen_room_data: RoomData = current_options[selected_index]

	# Hide the UI and tell the DungeonManager what was chosen.
	visible = false

	DungeonManager.confirm_draft_placement()

func _on_draft_cancelled():
	visible = false
	current_options.clear()
