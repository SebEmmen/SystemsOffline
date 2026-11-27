extends Control

@export_group("Error / Fixed Colors")
@export var error_border_color: Color = Color(1.0, 0.23, 0.19, 1.0)
@export var fixed_border_color: Color = Color(0.15, 0.9, 0.35, 1.0)
@export var error_text_color: Color = Color(1.0, 0.23, 0.19, 1.0)
@export var fixed_text_color: Color = Color(0.2, 1.0, 0.45, 1.0)

@export_group("Flash Settings")
@export var flash_speed: float = 0.45
@export var min_alpha: float = 0.25
@export var flash_when_fixed: bool = false

var _error_tweens: Dictionary = {}
var _panel_styles: Dictionary = {}
var _error_labels: Dictionary = {}
var _default_error_texts: Dictionary = {}


func _ready() -> void:
	for child in find_children("*", "PanelContainer", true, false):
		var panel := child as PanelContainer
		if panel == null:
			continue

		var style := panel.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			var unique_style := (style as StyleBoxFlat).duplicate(true) as StyleBoxFlat
			panel.add_theme_stylebox_override("panel", unique_style)
			_panel_styles[panel] = unique_style

		var lbl := _find_first_label(panel)
		if lbl != null:
			_error_labels[panel] = lbl
			_default_error_texts[panel] = lbl.text


func set_error_active(
	box: Control,
	active: bool,
	fixed: bool = false,
	fixed_text: String = "",
	error_text: String = ""
) -> void:
	if box == null:
		return

	_stop_tween(box)

	if not active and not fixed:
		box.visible = false
		box.modulate.a = 1.0
		return

	box.visible = true
	box.modulate.a = 1.0
	_apply_box_state(box, fixed, fixed_text, error_text)

	var should_flash := (not fixed) or flash_when_fixed
	if not should_flash:
		return

	var tween := create_tween().set_loops()
	tween.tween_property(box, "modulate:a", min_alpha, flash_speed) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(box, "modulate:a", 1.0, flash_speed) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	_error_tweens[box] = tween


func set_box_fixed(box: Control, is_fixed: bool, fixed_text: String = "", keep_visible: bool = true) -> void:
	set_error_active(box, keep_visible, is_fixed, fixed_text)


func _apply_box_state(box: Control, is_fixed: bool, fixed_text: String, error_text: String) -> void:
	var panel := box as PanelContainer
	if panel == null:
		panel = box.get_node_or_null("PanelContainer") as PanelContainer

	var lbl: Label = null
	if panel != null and _error_labels.has(panel):
		lbl = _error_labels[panel] as Label
	else:
		lbl = _find_first_label(box)

	if lbl != null:
		if is_fixed:
			if fixed_text != "":
				lbl.text = fixed_text
			lbl.add_theme_color_override("font_color", fixed_text_color)
		else:
			if error_text != "":
				lbl.text = error_text
			elif panel != null and _default_error_texts.has(panel):
				lbl.text = str(_default_error_texts[panel])
			lbl.add_theme_color_override("font_color", error_text_color)

	if panel != null:
		var style: StyleBoxFlat = _panel_styles.get(panel, null) as StyleBoxFlat
		if style == null:
			var existing := panel.get_theme_stylebox("panel")
			if existing is StyleBoxFlat:
				style = (existing as StyleBoxFlat).duplicate(true) as StyleBoxFlat
				panel.add_theme_stylebox_override("panel", style)
				_panel_styles[panel] = style
		if style != null:
			style.border_color = fixed_border_color if is_fixed else error_border_color


func _find_first_label(root: Node) -> Label:
	if root is Label:
		return root as Label
	for child in root.find_children("*", "Label", true, false):
		return child as Label
	return null


func _stop_tween(box: Control) -> void:
	if _error_tweens.has(box) and _error_tweens[box] != null:
		(_error_tweens[box] as Tween).kill()
		_error_tweens.erase(box)
