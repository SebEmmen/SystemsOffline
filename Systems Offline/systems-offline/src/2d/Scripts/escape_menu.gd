extends Control

## Pause Menu Controller for Systems Offline
## Developed by Kitefin Studios
## Matches the visual identity, typography, audio, and settings of the Main Menu.
## Operates seamlessly while gameplay is frozen, preserving player state.

# Node References
@onready var ui_manager: UI_Manager = get_parent() as UI_Manager
@onready var left_layout: VBoxContainer = $MenuRoot/LeftLayout
@onready var status_dot: Label = $MenuRoot/LeftLayout/Header/StatusHBox/StatusDot

# Navigation Buttons
@onready var resume_btn: Button = $MenuRoot/LeftLayout/Buttons/ResumeButton
@onready var settings_btn: Button = $MenuRoot/LeftLayout/Buttons/SettingsButton
@onready var main_menu_btn: Button = $MenuRoot/LeftLayout/Buttons/MainMenuButton
@onready var quit_btn: Button = $MenuRoot/LeftLayout/Buttons/QuitButton

# Modals
@onready var options_modal: Control = $Modals/OptionsModal
@onready var confirm_modal: Control = $Modals/ConfirmModal
@onready var confirm_title: Label = $Modals/ConfirmModal/Panel/VBox/Title
@onready var confirm_message: Label = $Modals/ConfirmModal/Panel/VBox/MessageLabel
@onready var confirm_ok_btn: Button = $Modals/ConfirmModal/Panel/VBox/HBox/ConfirmButton
@onready var confirm_cancel_btn: Button = $Modals/ConfirmModal/Panel/VBox/HBox/CancelButton

# Audio Players
@onready var sound_hover: AudioStreamPlayer = $Audio/SoundHover
@onready var sound_click: AudioStreamPlayer = $Audio/SoundClick
@onready var sound_confirm: AudioStreamPlayer = $Audio/SoundConfirm
@onready var sound_transition: AudioStreamPlayer = $Audio/SoundTransition

# Shader & Overlays
@onready var backdrop_rect: ColorRect = $PauseBackdrop
@onready var fade_rect: ColorRect = $FadeOverlay

# Settings UI References
@onready var master_slider: HSlider = $Modals/OptionsModal/Panel/VBox/TabContainer/Audio/Grid/MasterSlider
@onready var music_slider: HSlider = $Modals/OptionsModal/Panel/VBox/TabContainer/Audio/Grid/MusicSlider
@onready var sfx_slider: HSlider = $Modals/OptionsModal/Panel/VBox/TabContainer/Audio/Grid/SFXSlider
@onready var master_val_label: Label = $Modals/OptionsModal/Panel/VBox/TabContainer/Audio/Grid/MasterVal
@onready var music_val_label: Label = $Modals/OptionsModal/Panel/VBox/TabContainer/Audio/Grid/MusicVal
@onready var sfx_val_label: Label = $Modals/OptionsModal/Panel/VBox/TabContainer/Audio/Grid/SFXVal
@onready var window_mode_btn: OptionButton = $Modals/OptionsModal/Panel/VBox/TabContainer/Display/Grid/WindowModeBtn
@onready var vsync_check: CheckBox = $Modals/OptionsModal/Panel/VBox/TabContainer/Display/Grid/VSyncCheck
@onready var scanline_check: CheckBox = $Modals/OptionsModal/Panel/VBox/TabContainer/Display/Grid/ScanlineCheck
# State
enum ConfirmAction { NONE, RETURN_TO_MAIN_MENU, QUIT_GAME }
var pending_confirm_action: ConfirmAction = ConfirmAction.NONE
var is_transitioning: bool = false
var blink_timer: float = 0.0
var base_left_x: float = 64.0

const SETTINGS_FILE = "user://settings.json"
const MAIN_MENU_SCENE = "res://src/2d/Scenes/MainMenu.tscn"

func _ready() -> void:
	# Ensure this menu and its animations process while game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	if left_layout:
		base_left_x = left_layout.position.x

	_load_settings()
	_setup_connections()

	visibility_changed.connect(_on_visibility_changed)

func _process(delta: float) -> void:
	if not visible:
		return

	# Pulse status indicator dot
	blink_timer += delta
	if status_dot:
		var alpha = (sin(blink_timer * 3.5) + 1.0) * 0.5
		status_dot.modulate = Color(1.0, 0.4, 0.1, lerp(0.35, 1.0, alpha))

func _on_visibility_changed() -> void:
	if visible:
		# Reset modals
		if options_modal: options_modal.visible = false
		if confirm_modal: confirm_modal.visible = false
		pending_confirm_action = ConfirmAction.NONE
		is_transitioning = false

		_play_transition_sound()
		_animate_entrance()
		_load_settings()

func _animate_entrance() -> void:
	if not left_layout:
		return

	left_layout.modulate.a = 0.0
	left_layout.position.x = base_left_x - 24.0

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(left_layout, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(left_layout, "position:x", base_left_x, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _setup_connections() -> void:
	resume_btn.pressed.connect(_on_resume_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

	_attach_sound_feedback(self)

	# Modals close buttons
	$Modals/OptionsModal/Panel/VBox/Header/CloseBtn.pressed.connect(func(): _close_modal(options_modal))
	$Modals/ConfirmModal/Panel/VBox/HBox/CancelButton.pressed.connect(func(): _close_modal(confirm_modal))
	confirm_ok_btn.pressed.connect(_on_confirm_ok_pressed)

	# Settings controls
	master_slider.value_changed.connect(_on_master_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	window_mode_btn.item_selected.connect(_on_window_mode_selected)
	vsync_check.toggled.connect(_on_vsync_toggled)
	scanline_check.toggled.connect(_on_scanline_toggled)
	$Modals/OptionsModal/Panel/VBox/Footer/SaveSettingsBtn.pressed.connect(_save_settings)

func _attach_sound_feedback(node: Node) -> void:
	if node is Button:
		node.mouse_entered.connect(_play_hover_sound)
	for child in node.get_children():
		_attach_sound_feedback(child)

func _play_hover_sound() -> void:
	if sound_hover and not is_transitioning and visible:
		sound_hover.pitch_scale = randf_range(0.96, 1.05)
		sound_hover.play()

func _play_click_sound() -> void:
	if sound_click and not is_transitioning and visible:
		sound_click.play()

func _play_confirm_sound() -> void:
	if sound_confirm and not is_transitioning and visible:
		sound_confirm.play()

func _play_transition_sound() -> void:
	if sound_transition and not is_transitioning and visible:
		sound_transition.play()

# Button Handlers
func _on_resume_pressed() -> void:
	_play_click_sound()
	_resume_game()

func _on_settings_pressed() -> void:
	_play_click_sound()
	_open_modal(options_modal)

func _on_main_menu_pressed() -> void:
	_play_click_sound()
	pending_confirm_action = ConfirmAction.RETURN_TO_MAIN_MENU
	confirm_title.text = "// SAVE & RETURN"
	confirm_message.text = "Save current progress and return to Main Menu?"
	confirm_ok_btn.text = "SAVE & EXIT"
	_open_modal(confirm_modal)

func _on_quit_pressed() -> void:
	_play_click_sound()
	pending_confirm_action = ConfirmAction.QUIT_GAME
	confirm_title.text = "// SAVE & TERMINATE"
	confirm_message.text = "Save current mission progress and exit to desktop?"
	confirm_ok_btn.text = "EXIT GAME"
	_open_modal(confirm_modal)

func _on_confirm_ok_pressed() -> void:
	_play_confirm_sound()
	_close_modal(confirm_modal)
	match pending_confirm_action:
		ConfirmAction.RETURN_TO_MAIN_MENU:
			_save_and_return_to_main_menu()
		ConfirmAction.QUIT_GAME:
			_save_and_quit()
	pending_confirm_action = ConfirmAction.NONE

func _resume_game() -> void:
	if ui_manager:
		ui_manager.close_menu()
	else:
		visible = false
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		Callable(Input, "set_mouse_mode").call_deferred(Input.MOUSE_MODE_CAPTURED)
		var player = _get_player()
		if player and player.has_method("capture_mouse"):
			player.capture_mouse()
			player.call_deferred("capture_mouse")

func _save_and_return_to_main_menu() -> void:
	if is_transitioning:
		return
	is_transitioning = true

	# Save progress
	SaveManager.save_game()

	_play_transition_sound()
	if fade_rect:
		fade_rect.visible = true
		fade_rect.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(fade_rect, "modulate:a", 1.0, 0.35)
		tween.tween_callback(func():
			get_tree().paused = false
			get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		)
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _save_and_quit() -> void:
	if is_transitioning:
		return
	is_transitioning = true

	# Save progress
	SaveManager.save_game()

	_play_transition_sound()
	if fade_rect:
		fade_rect.visible = true
		fade_rect.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(fade_rect, "modulate:a", 1.0, 0.25)
		tween.tween_callback(func():
			get_tree().quit()
		)
	else:
		get_tree().quit()

# Modal Management
func _open_modal(modal: Control) -> void:
	_play_transition_sound()
	options_modal.visible = false
	confirm_modal.visible = false
	modal.visible = true

func _close_modal(modal: Control) -> void:
	_play_click_sound()
	modal.visible = false

## Handles ESC key while pause menu is active.
## Returns true if an active modal was closed (event consumed),
## or false if on the root pause menu (allowing resume).
func handle_cancel() -> bool:
	if confirm_modal and confirm_modal.visible:
		_close_modal(confirm_modal)
		return true
	if options_modal and options_modal.visible:
		_close_modal(options_modal)
		return true
	return false

# Settings Implementation (Synchronized with MainMenu)
func _on_master_slider_changed(value: float) -> void:
	master_val_label.text = "%d%%" % int(value * 100)
	_set_bus_volume("Master", value)

func _on_music_slider_changed(value: float) -> void:
	music_val_label.text = "%d%%" % int(value * 100)
	_set_bus_volume("Music", value)

func _on_sfx_slider_changed(value: float) -> void:
	sfx_val_label.text = "%d%%" % int(value * 100)
	_set_bus_volume("SFX", value)
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
	if backdrop_rect and backdrop_rect.material is ShaderMaterial:
		(backdrop_rect.material as ShaderMaterial).set_shader_parameter("enabled", enabled)

func _save_settings() -> void:
	_play_confirm_sound()
	var data = {
		"master_vol": master_slider.value,
		"music_vol": music_slider.value,
		"sfx_vol": sfx_slider.value,
		"window_mode": window_mode_btn.selected,
		"vsync": vsync_check.button_pressed,
		"scanline": scanline_check.button_pressed,
	}
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	_close_modal(options_modal)

func _load_settings() -> void:
	master_slider.value = 0.85
	music_slider.value = 0.75
	sfx_slider.value = 0.90
	window_mode_btn.select(0)
	vsync_check.button_pressed = true
	scanline_check.button_pressed = true

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

func _get_player() -> CharacterBody3D:
	if ui_manager and ui_manager.player:
		return ui_manager.player
	return get_tree().get_first_node_in_group("player") as CharacterBody3D
