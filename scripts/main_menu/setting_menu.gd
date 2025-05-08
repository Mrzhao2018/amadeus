extends PanelContainer

signal closed

const SETTINGS_FILE = "user://settings.cfg"
const PREFERRED_RESOLUTIONS = [
    Vector2i(1280, 720),
    Vector2i(1600, 900),
    Vector2i(1920, 1080),
    Vector2i(2560, 1440),
    Vector2i(3840, 2160) # 4K
]

#region Node References
@onready var tab_container: TabContainer = $VBoxContainer/MainVBox/TabContainer
# Graphics
@onready var resolution_option: OptionButton = $VBoxContainer/MainVBox/TabContainer/Graphics/GraphicsMarginContainer/GraphicsGrid/ResolutionOption
@onready var display_mode_option: OptionButton = $VBoxContainer/MainVBox/TabContainer/Graphics/GraphicsMarginContainer/GraphicsGrid/DisplayModeOption
@onready var v_sync_check_box: CheckBox = $VBoxContainer/MainVBox/TabContainer/Graphics/GraphicsMarginContainer/GraphicsGrid/VSyncCheckBox
@onready var quality_option: OptionButton = $VBoxContainer/MainVBox/TabContainer/Graphics/GraphicsMarginContainer/GraphicsGrid/QualityOption
@onready var shadow_quality_label: Label = $VBoxContainer/MainVBox/TabContainer/Graphics/GraphicsMarginContainer/GraphicsGrid/ShadowQualityLabel # Assuming you have this
@onready var shadow_quality_option: OptionButton = $VBoxContainer/MainVBox/TabContainer/Graphics/GraphicsMarginContainer/GraphicsGrid/ShadowQualityOption
@onready var aa_label: Label = $VBoxContainer/MainVBox/TabContainer/Graphics/GraphicsMarginContainer/GraphicsGrid/AALabel # Assuming you have this
@onready var aa_option: OptionButton = $VBoxContainer/MainVBox/TabContainer/Graphics/GraphicsMarginContainer/GraphicsGrid/AAOption
# Audio
@onready var master_slider: HSlider = $VBoxContainer/MainVBox/TabContainer/Audio/MarginContainer/AudioVBox/MasterVolumeHBox/MasterSlider
@onready var master_value_label: Label = $VBoxContainer/MainVBox/TabContainer/Audio/MarginContainer/AudioVBox/MasterVolumeHBox/MasterValueLabel
@onready var music_slider: HSlider = $VBoxContainer/MainVBox/TabContainer/Audio/MarginContainer/AudioVBox/MusicVolumeHBox/MusicSlider
@onready var music_value_label: Label = $VBoxContainer/MainVBox/TabContainer/Audio/MarginContainer/AudioVBox/MusicVolumeHBox/MusicValueLabel
@onready var sfx_slider: HSlider = $VBoxContainer/MainVBox/TabContainer/Audio/MarginContainer/AudioVBox/SfxVolumeHBox/SfxSlider
@onready var sfx_value_label: Label = $VBoxContainer/MainVBox/TabContainer/Audio/MarginContainer/AudioVBox/SfxVolumeHBox/SfxValueLabel
@onready var mute_check_box: CheckBox = $VBoxContainer/MainVBox/TabContainer/Audio/MarginContainer/AudioVBox/MuteHBox/MuteCheckBox
# Controls
@onready var sensitivity_slider: HSlider = $VBoxContainer/MainVBox/TabContainer/Controls/ControlsMarginContainer/ControlsVBoxContainer/ControlsGrid/SensitivityHBox/SensitivitySlider
@onready var sensitivity_value_label: Label = $VBoxContainer/MainVBox/TabContainer/Controls/ControlsMarginContainer/ControlsVBoxContainer/ControlsGrid/SensitivityHBox/SensitivityValueLabel
@onready var invert_mouse_y_check_box: CheckBox = $VBoxContainer/MainVBox/TabContainer/Controls/ControlsMarginContainer/ControlsVBoxContainer/ControlsGrid/InvertMouseYCheckBox
@onready var move_forward_button: Button = $VBoxContainer/MainVBox/TabContainer/Controls/ControlsMarginContainer/ControlsVBoxContainer/RemapGridContainer/MoveForwardButton
@onready var move_back_button: Button = $VBoxContainer/MainVBox/TabContainer/Controls/ControlsMarginContainer/ControlsVBoxContainer/RemapGridContainer/MoveBackButton
@onready var move_left_button: Button = $VBoxContainer/MainVBox/TabContainer/Controls/ControlsMarginContainer/ControlsVBoxContainer/RemapGridContainer/MoveLeftButton # Renamed from MoveLeftButton2 for clarity
@onready var move_right_button: Button = $VBoxContainer/MainVBox/TabContainer/Controls/ControlsMarginContainer/ControlsVBoxContainer/RemapGridContainer/MoveRightButton # Renamed from MoveRightButton3
@onready var interact_button: Button = $VBoxContainer/MainVBox/TabContainer/Controls/ControlsMarginContainer/ControlsVBoxContainer/RemapGridContainer/InteractButton
@onready var rebind_info_label: Label = $VBoxContainer/MainVBox/TabContainer/Controls/ControlsMarginContainer/ControlsVBoxContainer/RebindInfoLabel
# Actions
@onready var apply_button: Button = $VBoxContainer/ActionsHBox/ApplyButton
@onready var defaults_button: Button = $VBoxContainer/ActionsHBox/DefaultsButton
@onready var back_button: Button = $VBoxContainer/ActionsHBox/BackButton
#endregion

var current_settings = {}
var default_settings = {
	"graphics": {
		"resolution": Vector2i(1920,1080), # Use Vector2i for resolution
		"display_mode": DisplayServer.WINDOW_MODE_WINDOWED, # Use DisplayServer constants
		"v_sync": true,
		"quality": 2, # Index for "High"
		"shadow_quality": 3,
		"aa": 1
	},
	"audio": {
		"master_volume": 80.0, # Use float for consistency with slider
		"music_volume": 70.0,
		"sfx_volume": 90.0,
		"mute": false
	},
	"controls": {
		"sensitivity": 100.0,
		"invert_mouse_y": false,
		"move_forward": "W",
		"move_back": "S",
		"move_left": "A",
		"move_right": "D",
		"interact": "E",
	}
}
var dirty_settings: bool = false # Changed to bool for simplicity
var is_rebinding_action: String = "" # Stores the action name being rebound (e.g., "move_forward")
var _active_rebind_button: Button = null # Stores the button currently waiting for input


func _ready() -> void:
	apply_button.disabled = true
	rebind_info_label.visible = false

	_populate_resolution_options() # Populate before loading to match saved res
	load_settings() # Loads or uses defaults, then updates UI
	_connect_signals()
	_apply_audio_ui_from_current_settings() # Apply initial audio
	_update_custom_graphics_visibility() # Ensure correct visibility based on loaded quality

func _connect_signals():
	# Graphics
	display_mode_option.item_selected.connect(_on_setting_changed)
	resolution_option.item_selected.connect(_on_setting_changed)
	v_sync_check_box.toggled.connect(_on_setting_changed)
	quality_option.item_selected.connect(_on_quality_preset_changed) # Specific handler
	shadow_quality_option.item_selected.connect(_on_setting_changed) # If custom quality
	aa_option.item_selected.connect(_on_setting_changed) # If custom quality

	# Audio
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	mute_check_box.toggled.connect(_on_mute_toggled) # Changed handler name

	# Controls
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	invert_mouse_y_check_box.toggled.connect(_on_invert_mouse_y_toggled) # Changed handler name
	move_forward_button.pressed.connect(_start_rebind_process.bind("move_forward", move_forward_button))
	move_back_button.pressed.connect(_start_rebind_process.bind("move_back", move_back_button))
	move_left_button.pressed.connect(_start_rebind_process.bind("move_left", move_left_button))
	move_right_button.pressed.connect(_start_rebind_process.bind("move_right", move_right_button))
	interact_button.pressed.connect(_start_rebind_process.bind("interact", interact_button))

	# Action Buttons
	apply_button.pressed.connect(_on_apply_button_pressed) # Changed handler name
	defaults_button.pressed.connect(_on_defaults_button_pressed) # Changed handler name
	back_button.pressed.connect(_on_back_button_pressed) # Changed handler name

func _populate_resolution_options():
	resolution_option.clear()
	
	var current_primary_screen_size: Vector2i = DisplayServer.screen_get_size(DisplayServer.get_primary_screen())
	var current_window_size_setting: Vector2i = current_settings.get("graphics", {}).get("resolution", DisplayServer.window_get_size())

	var available_options: Array[Vector2i] = []

	# Add preferred resolutions that are smaller than or equal to the primary screen size
	for res in PREFERRED_RESOLUTIONS:
		if res.x <= current_primary_screen_size.x and res.y <= current_primary_screen_size.y:
			if not res in available_options: # Avoid duplicates
				available_options.append(res)
	
	# Ensure the user's primary screen resolution is an option, if not already added and sensible
	if not current_primary_screen_size in available_options:
		available_options.append(current_primary_screen_size)
		
	# Ensure the current saved/window resolution is an option, if not already added (important for startup)
	if not current_window_size_setting in available_options:
		# Only add if it's a reasonable size (e.g., not super small if something went wrong)
		if current_window_size_setting.x >= 640 and current_window_size_setting.y >= 480: # Example minimum
			available_options.append(current_window_size_setting)

	# Sort the resolutions for a cleaner list (e.g., by area or width)
	available_options.sort_custom(func(a: Vector2i, b: Vector2i): return (a.x * a.y) < (b.x * b.y))

	var selected_id_to_match = -1
	for i in range(available_options.size()):
		var res_option: Vector2i = available_options[i]
		resolution_option.add_item("%d x %d" % [res_option.x, res_option.y], i)
		resolution_option.set_item_metadata(i, res_option) # Store Vector2i in metadata
		if res_option == current_window_size_setting:
			selected_id_to_match = i
	
	if selected_id_to_match != -1:
		resolution_option.select(selected_id_to_match)
	elif resolution_option.item_count > 0:
		# Fallback: select the one closest to current primary screen size or largest available
		var best_fallback_idx = -1
		var smallest_diff = INF
		for i in range(resolution_option.item_count):
			var opt_res = resolution_option.get_item_metadata(i) as Vector2i
			var diff = (current_primary_screen_size - opt_res).length_squared()
			if diff < smallest_diff:
				smallest_diff = diff
				best_fallback_idx = i
		if best_fallback_idx != -1:
			resolution_option.select(best_fallback_idx)
		else: # Absolute fallback
			resolution_option.select(0)

	# If the resolution option list ended up empty, add at least the current window size or primary screen size
	if resolution_option.item_count == 0:
		var fallback_res = DisplayServer.window_get_size()
		if fallback_res.x < 640 : fallback_res = current_primary_screen_size # ensure reasonable
		resolution_option.add_item("%d x %d" % [fallback_res.x, fallback_res.y])
		resolution_option.set_item_metadata(0, fallback_res)
		resolution_option.select(0)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	
	if err != OK:
		printerr("Settings file not found or error loading (", err, "). Using defaults.")
		current_settings = default_settings.duplicate(true)
	else:
		current_settings = {} # Start fresh
		for section in default_settings.keys(): # Iterate default keys to ensure all sections exist
			current_settings[section] = {}
			for key in default_settings[section].keys():
				current_settings[section][key] = config.get_value(section, key, default_settings[section][key])

	_settings_to_ui()
	dirty_settings = false
	apply_button.disabled = true

func save_settings():
	# No need to call _ui_to_settings() here if apply_settings already did it
	var config = ConfigFile.new()
	for section in current_settings.keys():
		for key in current_settings[section].keys():
			config.set_value(section, key, current_settings[section][key])
			
	var err = config.save(SETTINGS_FILE)
	if err != OK:
		printerr("Error saving settings: ", err)
		
	dirty_settings = false
	apply_button.disabled = true
	print("Settings Saved")

func _on_apply_button_pressed():
	_ui_to_settings() # Ensure current_settings reflects UI before applying
	_apply_graphics_settings()
	_apply_audio_settings() # Audio is often applied live, but this ensures consistency if not
	_apply_control_settings()
	save_settings() # Save the now applied settings
	print("Settings Applied and Saved")

func _settings_to_ui():
	# Graphics
	var gfx = current_settings.graphics
	var res_idx_to_select = -1
	for i in range(resolution_option.item_count):
		if resolution_option.get_item_metadata(i) == gfx.resolution:
			res_idx_to_select = i
			break
	if res_idx_to_select != -1: resolution_option.select(res_idx_to_select)
	
	display_mode_option.select(gfx.display_mode)
	v_sync_check_box.button_pressed = gfx.v_sync
	quality_option.select(gfx.quality)
	# Custom graphics options might depend on quality_option's value
	_update_custom_graphics_visibility() # Call it after setting quality_option
	if shadow_quality_option.visible: shadow_quality_option.select(gfx.shadow_quality)
	if aa_option.visible: aa_option.select(gfx.aa)

	# Audio
	var audio = current_settings.audio
	master_slider.value = audio.master_volume
	_update_slider_label(master_slider, master_value_label)
	music_slider.value = audio.music_volume
	_update_slider_label(music_slider, music_value_label)
	sfx_slider.value = audio.sfx_volume
	_update_slider_label(sfx_slider, sfx_value_label)
	mute_check_box.button_pressed = audio.mute

	# Controls
	var controls = current_settings.controls
	sensitivity_slider.value = controls.sensitivity
	_update_slider_label(sensitivity_slider, sensitivity_value_label, false) # No %
	invert_mouse_y_check_box.button_pressed = controls.invert_mouse_y
	move_forward_button.text = controls.move_forward
	move_back_button.text = controls.move_back
	move_left_button.text = controls.move_left
	move_right_button.text = controls.move_right
	interact_button.text = controls.interact

func _ui_to_settings():
	# Graphics
	var gfx = current_settings.graphics
	var res_idx = resolution_option.selected
	if res_idx != -1: gfx.resolution = resolution_option.get_item_metadata(res_idx)
	gfx.display_mode = display_mode_option.selected
	gfx.v_sync = v_sync_check_box.button_pressed
	gfx.quality = quality_option.selected
	if shadow_quality_option.visible: gfx.shadow_quality = shadow_quality_option.selected
	if aa_option.visible: gfx.aa = aa_option.selected

	# Audio
	var audio = current_settings.audio
	audio.master_volume = master_slider.value
	audio.music_volume = music_slider.value
	audio.sfx_volume = sfx_slider.value
	audio.mute = mute_check_box.button_pressed

	# Controls
	var controls = current_settings.controls
	controls.sensitivity = sensitivity_slider.value
	controls.invert_mouse_y = invert_mouse_y_check_box.button_pressed
	# Keybinds are updated directly in _input during rebind, not here.

func _apply_graphics_settings():
	var gfx = current_settings.graphics
	
	# Apply display mode and VSync BEFORE resolution to avoid issues
	DisplayServer.window_set_mode(gfx.display_mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if gfx.v_sync else DisplayServer.VSYNC_DISABLED)
	
	# Apply resolution after mode change
	if gfx.display_mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		# It's generally safer to set min_size as well, or center window after resize
		DisplayServer.window_set_size(gfx.resolution)
		# Consider DisplayServer.window_set_position(DisplayServer.WINDOW_POSITION_CENTER_SCREEN)
	
	print("Applying Quality Preset (index):", gfx.quality)
	# TODO: Implement actual quality change logic (e.g., change global shaders, texture LODs)

func _apply_audio_settings(): # This function applies based on current_settings
	var audio = current_settings.audio
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(audio.master_volume / 100.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(audio.music_volume / 100.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(audio.sfx_volume / 100.0)) # Ensure "SFX" bus exists
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), audio.mute)

func _apply_audio_ui_from_current_settings(): # Called once in _ready
	var audio = current_settings.audio
	_apply_live_bus_volume("Master", audio.master_volume)
	_apply_live_bus_volume("Music", audio.music_volume)
	_apply_live_bus_volume("SFX", audio.sfx_volume)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), audio.mute)


func _apply_control_settings():
	var controls_map = current_settings.controls
	for action_name in controls_map.keys():
		if action_name == "sensitivity" or action_name == "invert_mouse_y":
			continue # These are not InputMap actions

		InputMap.action_erase_events(action_name) # Clear old bindings
		var key_name_or_code = controls_map[action_name]
		
		# Try to create event from string (more robust needed for mouse/joy)
		var new_event = InputEventKey.new()
		# This is a simplified way; ideally, store physical key codes or more detailed event data
		new_event.physical_keycode = OS.find_keycode_from_string(key_name_or_code)
		
		if new_event.physical_keycode != KEY_NONE:
			InputMap.action_add_event(action_name, new_event)
		else:
			printerr("Could not find keycode for: ", key_name_or_code, " for action ", action_name)
	
	print("Control settings (keybinds) applied to InputMap.")

func _on_setting_changed(_arg = null): # Accept any argument or none
	dirty_settings = true
	apply_button.disabled = false

func _on_quality_preset_changed(_index): # Argument is the selected index
	_update_custom_graphics_visibility()
	_on_setting_changed() # Mark dirty

func _update_custom_graphics_visibility():
	var selected_quality_text = ""
	if quality_option.selected != -1:
		selected_quality_text = quality_option.get_item_text(quality_option.selected).to_lower()
	
	var is_custom = (selected_quality_text == "自定义") # Make sure "自定义" is an actual item text
	
	shadow_quality_label.visible = is_custom
	shadow_quality_option.visible = is_custom
	aa_label.visible = is_custom
	aa_option.visible = is_custom
	
	# If switching away from custom, maybe reset shadow/aa to some default or disable them in current_settings
	if not is_custom:
		pass # Consider what to do with shadow/aa settings data

func _on_master_volume_changed(value: float):
	_update_slider_label(master_slider, master_value_label)
	_apply_live_bus_volume("Master", value)
	_on_setting_changed()

func _on_music_volume_changed(value: float):
	_update_slider_label(music_slider, music_value_label)
	_apply_live_bus_volume("Music", value)
	_on_setting_changed()

func _on_sfx_volume_changed(value: float):
	_update_slider_label(sfx_slider, sfx_value_label)
	_apply_live_bus_volume("SFX", value) # Ensure "SFX" bus exists
	_on_setting_changed()

func _on_mute_toggled(button_pressed: bool):
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), button_pressed)
	_on_setting_changed()

func _apply_live_bus_volume(bus_name: String, linear_value: float):
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_value / 100.0))
	else:
		printerr("Audio bus not found: ", bus_name)

func _on_sensitivity_changed(_value: float):
	_update_slider_label(sensitivity_slider, sensitivity_value_label, false) # No %
	_on_setting_changed()

func _on_invert_mouse_y_toggled(_button_pressed: bool):
	_on_setting_changed()

func _update_slider_label(slider: HSlider, label: Label, show_percent: bool = true):
	if label == null or slider == null: return # Guard against null nodes
	if show_percent:
		label.text = "%d%%" % int(slider.value)
	else:
		label.text = str(int(slider.value))

func _on_defaults_button_pressed():
	print("Restoring default settings UI")
	current_settings = default_settings.duplicate(true) 
	_settings_to_ui()
	_update_custom_graphics_visibility() # Ensure visibility matches new default quality
	dirty_settings = true # Mark as dirty so 'Apply' can save these defaults
	apply_button.disabled = false
	# Also apply audio immediately from defaults
	_apply_audio_ui_from_current_settings()

func _on_back_button_pressed():
	if is_rebinding_action != "": # Cancel active rebind if back is pressed
		_cancel_current_rebind()

	if dirty_settings:
		# TODO: Implement a ConfirmationDialog here
		# var dialog = ConfirmationDialog.new()
		# dialog.dialog_text = "You have unsaved changes. Apply them before exiting?"
		# dialog.get_ok_button().text = "Apply & Exit"
		# dialog.get_cancel_button().text = "Discard & Exit"
		# dialog.add_button("Cancel", true) # A third button to just close dialog
		# dialog.confirmed.connect(_on_apply_button_pressed) # Then emit closed
		# dialog.canceled.connect(func(): emit_signal("closed"))
		# add_child(dialog)
		# dialog.popup_centered()
		printerr("WARN: Unsaved changes! Emitting closed for now.")
		emit_signal("closed") 
	else:
		emit_signal("closed")


# --- Key Rebinding Logic ---
func _unhandled_input(event: InputEvent): # Use _unhandled_input for global listening
	if is_rebinding_action == "" or not _active_rebind_button: # Not in rebinding mode
		return

	if event.is_action_pressed("ui_cancel"): # Use an action for Esc
		_cancel_current_rebind()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.is_pressed():
		var key_event := event as InputEventKey
		var key_string: String = OS.get_keycode_string(key_event.get_physical_keycode_with_modifiers())
		
		# Basic validation (optional: check if key is already bound elsewhere significantly)
		if key_event.physical_keycode == KEY_UNKNOWN:
			rebind_info_label.text = "无效按键，请重试 (Esc 取消)"
			get_viewport().set_input_as_handled()
			return

		print("Rebinding action '%s' to key '%s'" % [is_rebinding_action, key_string])
		
		_active_rebind_button.text = key_string
		current_settings.controls[is_rebinding_action] = key_string # Update internal setting
		
		_on_setting_changed() # Mark as dirty
		_finish_rebind()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.is_pressed():
		# TODO: Handle mouse button rebinding (e.g., "Button 1", "Button 2")
		print("Mouse button rebinding not yet fully implemented.")
		# var mb_event := event as InputEventMouseButton
		# var mb_string = "Mouse " + str(mb_event.button_index)
		# _active_rebind_button.text = mb_string
		# current_settings.controls[is_rebinding_action] = mb_string
		# _on_setting_changed()
		# _finish_rebind()
		get_viewport().set_input_as_handled()

func _start_rebind_process(action_name: String, button_node: Button):
	if is_rebinding_action != "": # If already rebinding another key
		if _active_rebind_button: # Reset previous button's "waiting" state if any
			_active_rebind_button.disabled = false # Or revert style
		print("Cancelled previous rebind for: ", is_rebinding_action)

	is_rebinding_action = action_name
	_active_rebind_button = button_node
	_active_rebind_button.disabled = true # Visually indicate it's waiting
	# You might want to change style instead of disabling for better visual cue
	
	rebind_info_label.text = "请按下按键绑定 '%s' (Esc 取消)" % action_name
	rebind_info_label.visible = true
	
	# Disable other rebind buttons to prevent multiple active rebinds
	_set_rebind_buttons_interactive(false, _active_rebind_button)

func _finish_rebind():
	is_rebinding_action = ""
	if _active_rebind_button:
		_active_rebind_button.disabled = false # Re-enable the button
	_active_rebind_button = null
	rebind_info_label.visible = false
	_set_rebind_buttons_interactive(true)


func _cancel_current_rebind():
	if is_rebinding_action != "":
		print("Rebind cancelled for action: ", is_rebinding_action)
		if _active_rebind_button:
			_active_rebind_button.disabled = false # Or revert style
			# Optional: revert button text to original if not saved yet
			# _active_rebind_button.text = current_settings.controls[is_rebinding_action]
		_finish_rebind()


func _set_rebind_buttons_interactive(interactive: bool, except_button: Button = null):
	move_forward_button.disabled = not interactive if move_forward_button != except_button else move_forward_button.disabled
	move_back_button.disabled = not interactive if move_back_button != except_button else move_back_button.disabled
	move_left_button.disabled = not interactive if move_left_button != except_button else move_left_button.disabled
	move_right_button.disabled = not interactive if move_right_button != except_button else move_right_button.disabled
	interact_button.disabled = not interactive if interact_button != except_button else interact_button.disabled

# Note: The _get_rebind_button_for_action is no longer strictly needed if _start_rebind_process passes the button.
# If you still need it for other purposes:
func _get_rebind_button_for_action(action_name: String) -> Button:
	match action_name:
		"move_forward": return move_forward_button
		"move_back": return move_back_button
		"move_left": return move_left_button
		"move_right": return move_right_button
		"interact": return interact_button
		_: return null