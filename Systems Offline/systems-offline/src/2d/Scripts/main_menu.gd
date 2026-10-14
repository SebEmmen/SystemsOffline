extends Control

## Main Menu Controller for Systems Offline
## Developed by Kitefin Studios
## Features clean minimalist layout, 3D Room1 panoramic view,
## and complete audio/display/controls settings.

# Node References
@onready var panorama: Node3D = $Room1Panorama
@onready var continue_btn: Button = $CanvasLayer/MainMenuRoot/LeftLayout/Buttons/ContinueButton
@onready var new_game_btn: Button = $CanvasLayer/MainMenuRoot/LeftLayout/Buttons/NewGameButton
@onready var sectors_btn: Button = $CanvasLayer/MainMenuRoot/LeftLayout/Buttons/SectorsButton
@onready var settings_btn: Button = $CanvasLayer/MainMenuRoot/LeftLayout/Buttons/SettingsButton
@onready var quit_btn: Button = $CanvasLayer/MainMenuRoot/LeftLayout/Buttons/QuitButton
#@onready var credits_link_btn: Button = $CanvasLayer/MainMenuRoot/BottomBar/CreditsBtn

# Modals
@onready var options_modal: Control = $CanvasLayer/Modals/OptionsModal
@onready var credits_modal: Control = $CanvasLayer/Modals/CreditsModal
@onready var sector_modal: Control = $CanvasLayer/Modals/SectorSelectModal
@onready var confirm_modal: Control = $CanvasLayer/Modals/ConfirmModal
@onready var confirm_message: Label = $CanvasLayer/Modals/ConfirmModal/Panel/VBox/MessageLabel
@onready var confirm_ok_btn: Button = $CanvasLayer/Modals/ConfirmModal/Panel/VBox/HBox/ConfirmButton

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

# State
enum ConfirmAction { NONE, NEW_GAME_OVERWRITE, QUIT_GAME }
var pending_confirm_action: ConfirmAction = ConfirmAction.NONE
var is_loading_scene: bool = false
var blink_timer: float = 0.0

const SETTINGS_FILE = "user://settings.json"

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_update_save_state()
	_load_settings()
	_setup_connections()
	_play_fade_in()

func _process(delta: float) -> void:
	blink_timer += delta
	var dot = $CanvasLayer/MainMenuRoot/LeftLayout/Header/StatusHBox/StatusDot as Label
	if dot:
		var alpha = (sin(blink_timer * 3.5) + 1.0) * 0.5
		dot.modulate = Color(1.0, 0.4, 0.1, lerp(0.35, 1.0, alpha))

func _input(event: InputEvent) -> void:
	if is_loading_scene:
		return

	# Handle mouse motion for 3D parallax over Room1
	if event is InputEventMouseMotion:
		var viewport_size = get_viewport_rect().size
		if viewport_size.x > 0 and viewport_size.y > 0:
			var center = viewport_size * 0.5
			var normalized = (event.position - center) / center
			if panorama:
				panorama.update_mouse_position(normalized)

	# Escape key closes any active modal
	if event.is_action_pressed("ui_cancel"):
		if _close_any_active_modal():
			get_viewport().set_input_as_handled()

func _setup_connections() -> void:
	continue_btn.pressed.connect(_on_continue_pressed)
	new_game_btn.pressed.connect(_on_new_game_pressed)
	sectors_btn.pressed.connect(_on_sectors_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	#credits_link_btn.pressed.connect(_on_credits_pressed)

	_attach_sound_feedback(self)

	# Modal close buttons
	$CanvasLayer/Modals/OptionsModal/Panel/VBox/Header/CloseBtn.pressed.connect(func(): _close_modal(options_modal))
	$CanvasLayer/Modals/CreditsModal/Panel/VBox/Header/CloseBtn.pressed.connect(func(): _close_modal(credits_modal))
	$CanvasLayer/Modals/SectorSelectModal/Panel/VBox/Header/CloseBtn.pressed.connect(func(): _close_modal(sector_modal))
	$CanvasLayer/Modals/ConfirmModal/Panel/VBox/HBox/CancelButton.pressed.connect(func(): _close_modal(confirm_modal))
	confirm_ok_btn.pressed.connect(_on_confirm_ok_pressed)

	# Sector launch buttons
	$CanvasLayer/Modals/SectorSelectModal/Panel/VBox/Grid/Sector1/HBox/LaunchBtn.pressed.connect(func(): _load_level("res://src/3d/Scenes/rooms/Room1.tscn"))
	#$CanvasLayer/Modals/SectorSelectModal/Panel/VBox/Grid/Sector2/LaunchBtn.pressed.connect(func(): _load_level("res://src/3d/Scenes/rooms/Forest.tscn"))
	#$CanvasLayer/Modals/SectorSelectModal/Panel/VBox/Grid/Sector3/LaunchBtn.pressed.connect(func(): _load_level("res://src/3d/Scenes/rooms/Sector3.tscn"))

	# Settings controls
	master_slider.value_changed.connect(_on_master_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	window_mode_btn.item_selected.connect(_on_window_mode_selected)
	vsync_check.toggled.connect(_on_vsync_toggled)
	scanline_check.toggled.connect(_on_scanline_toggled)
	#sens_slider.value_changed.connect(_on_sens_slider_changed)
	#invert_y_check.toggled.connect(_on_invert_y_toggled)
	#fov_slider.value_changed.connect(_on_fov_slider_changed)
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
		continue_btn.tooltip_text = "Resume saved progress in Systems Offline."
		continue_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		continue_btn.tooltip_text = "No save data found."
		continue_btn.modulate = Color(0.65, 0.7, 0.75, 0.5)

# Button Handlers
func _on_continue_pressed() -> void:
	_play_confirm_sound()
	_load_game_with_transition(func(): SaveManager.load_game())

func _on_new_game_pressed() -> void:
	_play_click_sound()
	if SaveManager.has_save():
		pending_confirm_action = ConfirmAction.NEW_GAME_OVERWRITE
		confirm_message.text = "A saved mission already exists.\nStarting a new game will overwrite your save file.\nProceed?"
		confirm_ok_btn.text = "START NEW GAME"
		_open_modal(confirm_modal)
	else:
		_load_game_with_transition(func(): SaveManager.new_game())

func _on_sectors_pressed() -> void:
	_play_click_sound()
	_open_modal(sector_modal)

func _on_settings_pressed() -> void:
	_play_click_sound()
	_open_modal(options_modal)

func _on_credits_pressed() -> void:
	_play_click_sound()
	_open_modal(credits_modal)

func _on_quit_pressed() -> void:
	_play_click_sound()
	pending_confirm_action = ConfirmAction.QUIT_GAME
	confirm_message.text = "Are you sure you want to terminate session and exit Systems Offline?"
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
	_close_modal(sector_modal)
	_load_game_with_transition(func(): get_tree().change_scene_to_file(scene_path))

# Modals
func _open_modal(modal: Control) -> void:
	_play_transition_sound()
	options_modal.visible = false
	credits_modal.visible = false
	sector_modal.visible = false
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
	if sector_modal.visible:
		_close_modal(sector_modal)
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
		tween.tween_property(fade_rect, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func(): fade_rect.visible = false)

func _load_game_with_transition(load_action: Callable) -> void:
	if is_loading_scene:
		return
	is_loading_scene = true
	_play_transition_sound()
	if fade_rect:
		fade_rect.visible = true
		var tween = create_tween()
		tween.tween_property(fade_rect, "modulate:a", 1.0, 0.45)
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

#func _on_sens_slider_changed(value: float) -> void:
	#sens_val_label.text = "%.1fx" % value

func _on_invert_y_toggled(_enabled: bool) -> void:
	pass

#func _on_fov_slider_changed(value: float) -> void:
	#fov_val_label.text = "%d°" % int(value)
	#if panorama and panorama.has_node("Camera3D"):
		#(panorama.get_node("Camera3D") as Camera3D).fov = value

func _save_settings() -> void:
	_play_confirm_sound()
	var data = {
		"master_vol": master_slider.value,
		"music_vol": music_slider.value,
		"sfx_vol": sfx_slider.value,
		"window_mode": window_mode_btn.selected,
		"vsync": vsync_check.button_pressed,
		"scanline": scanline_check.button_pressed,
		#"sens": sens_slider.value,
		#"invert_y": invert_y_check.button_pressed,
		#"fov": fov_slider.value
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
	#sens_slider.value = 1.0
	#invert_y_check.button_pressed = false

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
		#if parsed.has("sens"): sens_slider.value = parsed["sens"]
		#if parsed.has("invert_y"): invert_y_check.button_pressed = parsed["invert_y"]
		#if parsed.has("fov"):
			#fov_slider.value = parsed["fov"]
			#_on_fov_slider_changed(parsed["fov"])
