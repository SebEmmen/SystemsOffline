extends Control

@export_group("Error Boxes")
@export var fuel_empty_box: Control
@export var fuel_empty_puzzle_id: String = ""
@export var fuel_empty_fixed_text: String = "FUEL READY"

@export var pipes_box: Control
@export var pipes_puzzle_id: String = ""
@export var pipes_fixed_text: String = "PIPES CONNECTED"

@export var tank_levels_box: Control
@export var tank_levels_puzzle_id: String = ""
@export var tank_levels_fixed_text: String = "LEVELS NOMINAL"

@export_group("Initial / Polling")
@export var flash_on_start: bool = true
@export var auto_refresh_from_save: bool = true
@export var poll_interval: float = 0.25

@export_group("Colors")
@export var error_border_color: Color = Color(1.0, 0.23, 0.19, 1.0)
@export var fixed_border_color: Color = Color(0.15, 0.9, 0.35, 1.0)
@export var error_text_color: Color = Color(1.0, 0.32, 0.28, 1.0)
@export var fixed_text_color: Color = Color(0.25, 1.0, 0.5, 1.0)

@export_group("Flash Settings")
@export var sharp_blink: bool = false
@export var flash_speed: float = 0.35
@export var box_min_alpha: float = 0.2
@export var text_min_alpha: float = 0.85
@export var flash_when_fixed: bool = false

var _box_tweens: Dictionary = {}
var _label_tweens: Dictionary = {}
var _styles: Dictionary = {}
var _labels: Dictionary = {}
var _error_texts: Dictionary = {}
var _last_fixed_state: Dictionary = {}
var _poll_timer: float = 0.0


func _ready() -> void:
	_register_box(fuel_empty_box)
	_register_box(pipes_box)
	_register_box(tank_levels_box)

	if SaveManager.has_signal("puzzle_completed"):
		SaveManager.connect("puzzle_completed", _on_save_puzzle_completed)

	if flash_on_start:
		refresh_all_from_save()


func _process(delta: float) -> void:
	if not auto_refresh_from_save:
		return
	_poll_timer += delta
	if _poll_timer >= poll_interval:
		_poll_timer = 0.0
		refresh_all_from_save()


func refresh_all_from_save() -> void:
	_refresh_single_box(fuel_empty_box, fuel_empty_puzzle_id, fuel_empty_fixed_text)
	_refresh_single_box(pipes_box, pipes_puzzle_id, pipes_fixed_text)
	_refresh_single_box(tank_levels_box, tank_levels_puzzle_id, tank_levels_fixed_text)


func set_box_state(
	box: Control,
	active: bool,
	fixed: bool = false,
	fixed_text: String = "",
	error_text: String = ""
) -> void:
	if box == null:
		return

	_stop_tweens(box)

	if not active and not fixed:
		box.visible = false
		box.modulate = Color.WHITE
		return

	box.visible = true
	box.modulate = Color.WHITE
	var lbl := _apply_state(box, fixed, fixed_text, error_text)
	if lbl != null:
		lbl.modulate = Color.WHITE

	if fixed and not flash_when_fixed:
		return

	var box_tween := create_tween().set_loops()
	if sharp_blink:
		box_tween.tween_property(box, "modulate:a", box_min_alpha, 0.01)
		box_tween.tween_interval(flash_speed)
		box_tween.tween_property(box, "modulate:a", 1.0, 0.01)
		box_tween.tween_interval(flash_speed)
	else:
		box_tween.tween_property(box, "modulate:a", box_min_alpha, flash_speed) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
		box_tween.tween_property(box, "modulate:a", 1.0, flash_speed) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
	_box_tweens[box] = box_tween

	if lbl != null and text_min_alpha < 1.0:
		var lbl_tween := create_tween().set_loops()
		if sharp_blink:
			lbl_tween.tween_property(lbl, "modulate:a", text_min_alpha, 0.01)
			lbl_tween.tween_interval(flash_speed)
			lbl_tween.tween_property(lbl, "modulate:a", 1.0, 0.01)
			lbl_tween.tween_interval(flash_speed)
		else:
			lbl_tween.tween_property(lbl, "modulate:a", text_min_alpha, flash_speed) \
				.set_trans(Tween.TRANS_SINE) \
				.set_ease(Tween.EASE_IN_OUT)
			lbl_tween.tween_property(lbl, "modulate:a", 1.0, flash_speed) \
				.set_trans(Tween.TRANS_SINE) \
				.set_ease(Tween.EASE_IN_OUT)
		_label_tweens[box] = lbl_tween


func _refresh_single_box(box: Control, puzzle_id: String, fixed_text: String) -> void:
	if box == null:
		return

	var is_fixed := false
	if puzzle_id != "":
		is_fixed = SaveManager.is_puzzle_completed(puzzle_id)

	var prev_state = _last_fixed_state.get(box, null)
	if prev_state != null and bool(prev_state) == is_fixed and _box_tweens.has(box):
		return

	_last_fixed_state[box] = is_fixed
	# Shows active error when not fixed, and switches text + border when fixed.
	set_box_state(box, true, is_fixed, fixed_text)


func _on_save_puzzle_completed(_id: String) -> void:
	refresh_all_from_save()


func _register_box(box: Control) -> void:
	if box == null:
		return

	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := _find_panel(box)
	if panel != null:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := panel.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			var dup := (style as StyleBoxFlat).duplicate(true) as StyleBoxFlat
			panel.add_theme_stylebox_override("panel", dup)
			_styles[box] = dup

	var lbl := _find_label(box)
	if lbl != null:
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_labels[box] = lbl
		_error_texts[box] = lbl.text


func _apply_state(box: Control, is_fixed: bool, fixed_text: String, error_text: String) -> Label:
	var lbl: Label = _labels.get(box, _find_label(box)) as Label
	if lbl != null:
		var target_color := fixed_text_color if is_fixed else error_text_color

		if is_fixed:
			if fixed_text != "":
				lbl.text = fixed_text
		else:
			if error_text != "":
				lbl.text = error_text
			elif _error_texts.has(box):
				lbl.text = str(_error_texts[box])

		lbl.add_theme_color_override("font_color", target_color)

		if lbl.label_settings != null:
			var settings := lbl.label_settings.duplicate(true) as LabelSettings
			settings.font_color = target_color
			lbl.label_settings = settings

	var style: StyleBoxFlat = _styles.get(box, null) as StyleBoxFlat
	if style != null:
		style.border_color = fixed_border_color if is_fixed else error_border_color

	return lbl


func _find_panel(root: Node) -> PanelContainer:
	if root is PanelContainer:
		return root as PanelContainer
	for child in root.find_children("*", "PanelContainer", true, false):
		return child as PanelContainer
	return null


func _find_label(root: Node) -> Label:
	if root is Label:
		return root as Label
	for child in root.find_children("*", "Label", true, false):
		return child as Label
	return null


func _stop_tweens(box: Control) -> void:
	if _box_tweens.has(box) and _box_tweens[box] != null:
		(_box_tweens[box] as Tween).kill()
		_box_tweens.erase(box)
	if _label_tweens.has(box) and _label_tweens[box] != null:
		(_label_tweens[box] as Tween).kill()
		_label_tweens.erase(box)
