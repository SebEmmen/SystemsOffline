extends Control

## Main Menu Controller for Systems Offline
## Developed by Kitefin Studios
## Features full audio, graphics, and controls configuration,
## level selection, save loading, and interactive 3D panorama controls.

# Node References
@onready var panorama: Node3D = $MenuPanorama
@onready var ui_canvas: CanvasLayer = $CanvasLayer
@onready var main_menu_panel: Control = $CanvasLayer/MainMenuRoot
@onready var title_label: Label = $CanvasLayer/MainMenuRoot/LeftContainer/Header/GameTitle
@onready var offline_tag: Label = $CanvasLayer/MainMenuRoot/LeftContainer/Header/OfflineTag

# Navigation Buttons
@onready var continue_btn: Button = $CanvasLayer/MainMenuRoot/LeftContainer/MenuButtons/ContinueButton
@onready var new_game_btn: Button = $CanvasLayer/MainMenuRoot/LeftContainer/MenuButtons/NewGameButton
@onready var level_select_btn: Button = $CanvasLayer/MainMenuRoot/LeftContainer/MenuButtons/LevelSelectButton
@onready var options_btn: Button = $CanvasLayer/MainMenuRoot/LeftContainer/MenuButtons/OptionsButton
@onready var credits_btn: Button = $CanvasLayer/MainMenuRoot/LeftContainer/MenuButtons/CreditsButton
@onready var panorama_btn: Button = $CanvasLayer/MainMenuRoot/LeftContainer/MenuButtons/PanoramaButton
@onready var view_toggle_btn: Button = $CanvasLayer/MainMenuRoot/LeftContainer/MenuButtons/ViewToggleBtn
@onready var quit_btn: Button = $CanvasLayer/MainMenuRoot/LeftContainer/MenuButtons/QuitButton

# Modals
@onready var options_modal: Control = $CanvasLayer/Modals/OptionsModal
@onready var credits_modal: Control = $CanvasLayer/Modals/CreditsModal
@onready var level_modal: Control = $CanvasLayer/Modals/LevelSelectModal
@onready var confirm_modal: Control = $CanvasLayer/Modals/ConfirmModal
@onready var confirm_message: Label = $CanvasLayer/Modals/ConfirmModal/Panel/VBox/MessageLabel
@onready var confirm_ok_btn: Button = $CanvasLayer/Modals/ConfirmModal/Panel/VBox/HBox/ConfirmButton

# Panoramic View HUD
@onready var panorama_hud: Control = $CanvasLayer/PanoramaHUD
@onready var panorama_hud_label: Label = $CanvasLayer/PanoramaHUD/HintLabel

# Audio Players
@onready var sound_hover: AudioStreamPlayer = $Audio/SoundHover
@onready var sound_click: AudioStreamPlayer = $Audio/SoundClick
@onready var sound_confirm: AudioStreamPlayer = $Audio/SoundConfirm
@onready var sound_transition: AudioStreamPlayer = $Audio/SoundTransition

# Shader & Fade Overlay
@onready var scanline_rect: ColorRect = $CanvasLayer/ScanlineOverlay
@onready var fade_rect: ColorRect = $CanvasLayer/FadeOverlay

# Settings UI References
@onready var master_slider: HSlider = $CanvasLayer/Modals/OptionsModal/Panel/VBox/TabContainer/Audio/Grid/MasterSlider
@onready var music_slider: HSlider = $CanvasLayer/Modals/OptionsModal/Panel/VBox/TabContainer/Audio/Grid/MusicSlider
@onready var sfx_slider: HSlider = $CanvasLayer/Modals/OptionsModal/Panel/VBox/TabContainer/Audio/Grid/SFXSlider
@onready var master_val_label: Label = $CanvasLayer/Modals/OptionsModal/Panel/VBox/TabContainer/Audio/Grid/MasterVal
@onready var music_val_label: Label = $CanvasLayer/Modals/OptionsModal/Panel/VBox/TabContainer/Audio/Grid/MusicVal
@onready var sfx_val_label: Label = $CanvasLayer/Modals/OptionsModal/Panel/VBox/TabContainer/Audio/Grid/SFXVal
@onready var window_mode_btn: OptionButton = $CanvasLayer/Modals/OptionsModal/Panel/VBox/TabContainer/Display/Grid/WindowModeBtn
@onready var vsync_check: CheckBox = $CanvasLayer/Modals/OptionsModal/Panel/VBox/TabContainer/Display/Grid/VSyncCheck
@onready var scanline_check: CheckBox = $CanvasLayer/Modals/OptionsModal/Panel/VBox/TabContainer/Display/Grid/ScanlineCheck
@onready var glow_check: CheckBox = $CanvasLayer/Modals/OptionsModal/Panel/VBox/TabContainer/Display/Grid/GlowCheck
@onready var sens_val_label: Label = $CanvasLayer/Modals/OptionsModal/Panel/VBox/TabContainer/Controls/VBoxControls/Grid/SensVal
@onready var sens_slider: HSlider = $CanvasLayer/Modals/OptionsModal/Panel/VBox/TabContainer/Controls/VBoxControls/Grid/SensSlider
@onready var invert_y_check: CheckBox = $CanvasLayer/Modals/OptionsModal/Panel/VBox/TabContainer/Controls/VBoxControls/Grid/InvertYCheck
@onready var fov_slider: HSlider = $CanvasLayer/Modals/OptionsModal/Panel/VBox/TabContainer/Controls/VBoxControls/Grid/FOVSlider
@onready var fov_val_label: Label = $CanvasLayer/Modals/OptionsModal/Panel/VBox/TabContainer/Controls/VBoxControls/Grid/FOVVal

# State
enum ConfirmAction { NONE, NEW_GAME_OVERWRITE, QUIT_GAME }
var pending_confirm_action: ConfirmAction = ConfirmAction.NONE
var is_in_panorama_mode: bool = false
var is_loading_scene: bool = false
var blink_timer: float = 0.0

const SETTINGS_FILE = "user://settings.json"

func _ready() -> void:
	# Ensure mouse is visible and released
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Initial UI state
	_update_save_state()
	_load_settings()
	_setup_connections()
	_play_fade_in()
	
	# Update viewpoint label
	if panorama and view_toggle_btn:
		view_toggle_btn.text = "VIEW: %s" % panorama.get_current_view_name().to_upper()

func _process(delta: float) -> void:
	# Blink offline status indicator
	blink_timer += delta
	if offline_tag:
		var alpha = (sin(blink_timer * 3.5) + 1.0) * 0.5
		offline_tag.modulate = Color(1.0, 0.35, 0.15, lerp(0.4, 1.0, alpha))

func _input(event: InputEvent) -> void:
	if is_loading_scene:
		return

	# Handle mouse motion for panorama parallax & free look
	if event is InputEventMouseMotion:
		if is_in_panorama_mode:
			if panorama:
				panorama.handle_pan_input(event.relative)
		else:
			var viewport_size = get_viewport_rect().size
			if viewport_size.x > 0 and viewport_size.y > 0:
				var center = viewport_size * 0.5
				var normalized = (event.position - center) / center
				if panorama:
					panorama.update_mouse_position(normalized)

	# Exit panorama mode on any key or mouse click
	if is_in_panorama_mode:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
			_exit_panorama_mode()
			get_viewport().set_input_as_handled()
			return

	# Escape key closes active modal
	if event.is_action_pressed("ui_cancel"):
		if _close_any_active_modal():
			get_viewport().set_input_as_handled()

func _setup_connections() -> void:
	# Main buttons
	continue_btn.pressed.connect(_on_continue_pressed)
	new_game_btn.pressed.connect(_on_new_game_pressed)
	level_select_btn.pressed.connect(_on_level_select_pressed)
	options_btn.pressed.connect(_on_options_pressed)
	credits_btn.pressed.connect(_on_credits_pressed)
	panorama_btn.pressed.connect(_on_panorama_pressed)
	view_toggle_btn.pressed.connect(_on_view_toggle_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

	# Audio hover feedback on all buttons
	_attach_sound_feedback(self)

	# Modals close buttons
	$CanvasLayer/Modals/OptionsModal/Panel/VBox/Header/CloseBtn.pressed.connect(func(): _close_modal(options_modal))
	$CanvasLayer/Modals/CreditsModal/Panel/VBox/Header/CloseBtn.pressed.connect(func(): _close_modal(credits_modal))
	$CanvasLayer/Modals/LevelSelectModal/Panel/VBox/Header/CloseBtn.pressed.connect(func(): _close_modal(level_modal))
	$CanvasLayer/Modals/ConfirmModal/Panel/VBox/HBox/CancelButton.pressed.connect(func(): _close_modal(confirm_modal))
	confirm_ok_btn.pressed.connect(_on_confirm_ok_pressed)

	# Level buttons
	$CanvasLayer/Modals/LevelSelectModal/Panel/VBox/Grid/Level1/HBox/LaunchBtn.pressed.connect(func(): _load_level("res://src/3d/Scenes/rooms/Room1.tscn"))
	var level_2_btn := get_node_or_null(
		"CanvasLayer/Modals/LevelSelectModal/Panel/VBox/Grid/Level2/HBox/LaunchBtn"
	) as Button

	if level_2_btn:
		level_2_btn.pressed.connect(
			func(): _load_level("res://src/3d/Scenes/rooms/Forest.tscn")
		)
	# Settings controls
	master_slider.value_changed.connect(_on_master_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	window_mode_btn.item_selected.connect(_on_window_mode_selected)
	vsync_check.toggled.connect(_on_vsync_toggled)
	scanline_check.toggled.connect(_on_scanline_toggled)
	glow_check.toggled.connect(_on_glow_toggled)
	sens_slider.value_changed.connect(_on_sens_slider_changed)
	invert_y_check.toggled.connect(_on_invert_y_toggled)
	fov_slider.value_changed.connect(_on_fov_slider_changed)
	$CanvasLayer/Modals/OptionsModal/Panel/VBox/Footer/SaveSettingsBtn.pressed.connect(_save_settings)

func _attach_sound_feedback(node: Node) -> void:
	if node is Button:
		node.mouse_entered.connect(_play_hover_sound)
	for child in node.get_children():
		_attach_sound_feedback(child)

func _play_hover_sound() -> void:
	if sound_hover and not is_loading_scene:
		sound_hover.pitch_scale = randf_range(0.96, 1.05)
		sound_hover.play()

func _play_click_sound() -> void:
	if sound_click and not is_loading_scene:
		sound_click.play()

func _play_confirm_sound() -> void:
	if sound_confirm and not is_loading_scene:
		sound_confirm.play()

func _play_transition_sound() -> void:
	if sound_transition and not is_loading_scene:
		sound_transition.play()

func _update_save_state() -> void:
	var has_save = SaveManager.has_save()
	continue_btn.disabled = not has_save
	if has_save:
		continue_btn.tooltip_text = "Resume your saved progress in Systems Offline."
		continue_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		continue_btn.tooltip_text = "No save data found. Start a new game to begin."
		continue_btn.modulate = Color(0.65, 0.7, 0.75, 0.6)

# Button Handlers
func _on_continue_pressed() -> void:
	_play_confirm_sound()
	_load_game_with_transition(func(): SaveManager.load_game())

func _on_new_game_pressed() -> void:
	_play_click_sound()
	if SaveManager.has_save():
		pending_confirm_action = ConfirmAction.NEW_GAME_OVERWRITE
		confirm_message.text = "A saved mission already exists in memory.\nStarting a new game will overwrite your progress.\nAre you sure you want to proceed?"
		confirm_ok_btn.text = "START NEW GAME"
		_open_modal(confirm_modal)
	else:
		_load_game_with_transition(func(): SaveManager.new_game())

func _on_level_select_pressed() -> void:
	_play_click_sound()
	_open_modal(level_modal)

func _on_options_pressed() -> void:
	_play_click_sound()
	_open_modal(options_modal)

func _on_credits_pressed() -> void:
	_play_click_sound()
	_open_modal(credits_modal)

func _on_panorama_pressed() -> void:
	_play_click_sound()
	_enter_panorama_mode()

func _on_view_toggle_pressed() -> void:
	_play_click_sound()
	if panorama:
		var view_name = panorama.next_viewpoint()
		view_toggle_btn.text = "VIEW: %s" % view_name.to_upper()

func _on_quit_pressed() -> void:
	_play_click_sound()
	pending_confirm_action = ConfirmAction.QUIT_GAME
	confirm_message.text = "Are you sure you want to terminate the terminal session and exit Systems Offline?"
	confirm_ok_btn.text = "EXIT GAME"
	_open_modal(confirm_modal)

func _on_confirm_ok_pressed() -> void:
	_play_confirm_sound()
	_close_modal(confirm_modal)
	match pending_confirm_action:
		ConfirmAction.NEW_GAME_OVERWRITE:
			_load_game_with_transition(func(): SaveManager.new_game())
		ConfirmAction.QUIT_GAME:
			get_tree().quit()
	pending_confirm_action = ConfirmAction.NONE

func _load_level(scene_path: String) -> void:
	_close_modal(level_modal)
	_load_game_with_transition(func(): get_tree().change_scene_to_file(scene_path))

# Panorama Mode
func _enter_panorama_mode() -> void:
	is_in_panorama_mode = true
	main_menu_panel.visible = false
	panorama_hud.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if panorama:
		panorama.set_panoramic_mode(true)

func _exit_panorama_mode() -> void:
	is_in_panorama_mode = false
	main_menu_panel.visible = true
	panorama_hud.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if panorama:
		panorama.set_panoramic_mode(false)

# Modals
func _open_modal(modal: Control) -> void:
	_play_transition_sound()
	options_modal.visible = false
	credits_modal.visible = false
	level_modal.visible = false
	confirm_modal.visible = false
	modal.visible = true

func _close_modal(modal: Control) -> void:
	_play_click_sound()
	modal.visible = false

func _close_any_active_modal() -> bool:
	if options_modal.visible:
		_close_modal(options_modal)
		return true
	if credits_modal.visible:
		_close_modal(credits_modal)
		return true
	if level_modal.visible:
		_close_modal(level_modal)
		return true
	if confirm_modal.visible:
		_close_modal(confirm_modal)
		return true
	return false

# Transitions
func _play_fade_in() -> void:
	if fade_rect:
		fade_rect.visible = true
		fade_rect.modulate = Color(1, 1, 1, 1)
		var tween = create_tween()
		tween.tween_property(fade_rect, "modulate:a", 0.0, 0.6)
		tween.tween_callback(func(): fade_rect.visible = false)

func _load_game_with_transition(load_action: Callable) -> void:
	if is_loading_scene:
		return
	is_loading_scene = true
	_play_transition_sound()
	
	if fade_rect:
		fade_rect.visible = true
		var tween = create_tween()
		tween.tween_property(fade_rect, "modulate:a", 1.0, 0.5)
		tween.tween_callback(load_action)
	else:
		load_action.call()

# Settings Implementation
func _on_master_slider_changed(value: float) -> void:
	master_val_label.text = "%d%%" % int(value * 100)
	_set_bus_volume("Master", value)

func _on_music_slider_changed(value: float) -> void:
	music_val_label.text = "%d%%" % int(value * 100)
	_set_bus_volume("Music", value)

func _on_sfx_slider_changed(value: float) -> void:
	sfx_val_label.text = "%d%%" % int(value * 100)
	_set_bus_volume("SFX", value)
	# Sound test chirp
	if sound_hover:
		sound_hover.play()

func _set_bus_volume(bus_name: String, normalized_vol: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		if normalized_vol <= 0.01:
			AudioServer.set_bus_mute(idx, true)
		else:
			AudioServer.set_bus_mute(idx, false)
			var db = linear_to_db(normalized_vol)
			AudioServer.set_bus_volume_db(idx, db)

func _on_window_mode_selected(index: int) -> void:
	match index:
		0: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		1: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		2: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _on_vsync_toggled(enabled: bool) -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	)

func _on_scanline_toggled(enabled: bool) -> void:
	if scanline_rect and scanline_rect.material is ShaderMaterial:
		(scanline_rect.material as ShaderMaterial).set_shader_parameter("enabled", enabled)

func _on_glow_toggled(enabled: bool) -> void:
	if panorama and panorama.has_node("WorldEnvironment"):
		var we = panorama.get_node("WorldEnvironment") as WorldEnvironment
		if we and we.environment:
			we.environment.glow_enabled = enabled

func _on_sens_slider_changed(value: float) -> void:
	sens_val_label.text = "%.1fx" % value

func _on_invert_y_toggled(_enabled: bool) -> void:
	pass

func _on_fov_slider_changed(value: float) -> void:
	fov_val_label.text = "%d°" % int(value)
	if panorama and panorama.has_node("Camera3D"):
		(panorama.get_node("Camera3D") as Camera3D).fov = value

func _save_settings() -> void:
	_play_confirm_sound()
	var data = {
		"master_vol": master_slider.value,
		"music_vol": music_slider.value,
		"sfx_vol": sfx_slider.value,
		"window_mode": window_mode_btn.selected,
		"vsync": vsync_check.button_pressed,
		"scanline": scanline_check.button_pressed,
		"glow": glow_check.button_pressed,
		"sens": sens_slider.value,
		"invert_y": invert_y_check.button_pressed,
		"fov": fov_slider.value
	}
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	_close_modal(options_modal)

func _load_settings() -> void:
	# Default control values
	master_slider.value = 0.85
	music_slider.value = 0.75
	sfx_slider.value = 0.90
	window_mode_btn.select(0)
	vsync_check.button_pressed = true
	scanline_check.button_pressed = true
	glow_check.button_pressed = true
	sens_slider.value = 1.0
	invert_y_check.button_pressed = false
	fov_slider.value = 75.0

	if not FileAccess.file_exists(SETTINGS_FILE):
		return

	var file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	if not file:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if parsed is Dictionary:
		if parsed.has("master_vol"): master_slider.value = parsed["master_vol"]
		if parsed.has("music_vol"): music_slider.value = parsed["music_vol"]
		if parsed.has("sfx_vol"): sfx_slider.value = parsed["sfx_vol"]
		if parsed.has("window_mode"):
			window_mode_btn.select(int(parsed["window_mode"]))
			_on_window_mode_selected(int(parsed["window_mode"]))
		if parsed.has("vsync"):
			vsync_check.button_pressed = parsed["vsync"]
			_on_vsync_toggled(parsed["vsync"])
		if parsed.has("scanline"):
			scanline_check.button_pressed = parsed["scanline"]
			_on_scanline_toggled(parsed["scanline"])
		if parsed.has("glow"):
			glow_check.button_pressed = parsed["glow"]
			_on_glow_toggled(parsed["glow"])
		if parsed.has("sens"): sens_slider.value = parsed["sens"]
		if parsed.has("invert_y"): invert_y_check.button_pressed = parsed["invert_y"]
		if parsed.has("fov"):
			fov_slider.value = parsed["fov"]
			_on_fov_slider_changed(parsed["fov"])
