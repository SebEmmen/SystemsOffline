extends Control
## The Four Glyphs - Godot 4.x
## Attach to a single Control node. The whole UI is built in code.
## Add harder seals by appending to LEVELS.

signal solved(level_index: int)   # connect this to your door/unlock logic
signal all_solved

const BG := Color("0f1a19")
const SLAB := Color("1b2b28")
const WELL := Color("0a1211")
const BRASS := Color("c9a24b")
const BRASS_D := Color("7d6428")
const TEAL := Color("6fc2b0")
const INK := Color("e9e3d1")
const DIM := Color("8fa39d")
const BAD := Color("d1624f")

# order = dial order (left to right); values = the solution; eqs = [left, op, right, result]
const LEVELS := [
	{
		"name": "Seal I",
		"order": ["circle", "square", "triangle", "diamond"],
		"values": {"circle": 2, "square": 4, "triangle": 5, "diamond": 7},  # 2457
		"eqs": [
			["square", "+", "circle", 6],
			["triangle", "-", "square", 1],
			["diamond", "-", "triangle", 2],
			["circle", "+", "circle", 4],
		],
	},
]

var level := 0
var is_solved := false
var vals: Array[int] = []
var dial_labels: Array[Label] = []
var drag_accum := 0.0

var slab: PanelContainer
var eq_box: VBoxContainer
var dial_row: HBoxContainer
var go_btn: Button
var msg: Label
var lvl_label: Label


# ---------- glyph drawing ----------
class Glyph extends Control:
	var kind := "circle"
	var col := Color("6fc2b0")

	func _init(k: String = "circle", px: float = 44.0, c: Color = Color("6fc2b0")) -> void:
		kind = k
		col = c
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size.x
		var ctr := size / 2.0
		var fill := Color(col, 0.25)
		var w := maxf(2.0, s * 0.06)
		match kind:
			"circle":
				draw_circle(ctr, s * 0.33, fill)
				draw_circle(ctr, s * 0.33, col, false, w, true)
			"square":
				var r := Rect2(s * 0.2, s * 0.2, s * 0.6, s * 0.6)
				draw_rect(r, fill)
				draw_rect(r, col, false, w)
			"triangle":
				_poly([Vector2(0.5, 0.17), Vector2(0.85, 0.8), Vector2(0.15, 0.8)], fill, w)
			"diamond":
				_poly([Vector2(0.5, 0.12), Vector2(0.88, 0.5), Vector2(0.5, 0.88), Vector2(0.12, 0.5)], fill, w)

	func _poly(norm: Array, fill: Color, w: float) -> void:
		var pts := PackedVector2Array()
		for p in norm:
			pts.append(p * size.x)
		draw_colored_polygon(pts, fill)
		pts.append(pts[0])
		draw_polyline(pts, col, w, true)


# ---------- helpers ----------
func _box(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(10)
	return sb


func _label(text: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


# ---------- build ----------
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Fill the whole viewport (works for any SubViewport size)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	add_child(margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 18)
	margin.add_child(main)

	slab = PanelContainer.new()
	slab.add_theme_stylebox_override("panel", _box(SLAB, BRASS_D, 2, 6))
	slab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slab.size_flags_stretch_ratio = 3.0
	eq_box = VBoxContainer.new()
	eq_box.add_theme_constant_override("separation", 6)
	slab.add_child(eq_box)
	main.add_child(slab)

	lvl_label = _label("", 16, DIM)
	lvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	main.add_child(lvl_label)

	dial_row = HBoxContainer.new()
	dial_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dial_row.size_flags_stretch_ratio = 2.0
	dial_row.add_theme_constant_override("separation", 12)
	main.add_child(dial_row)

	go_btn = Button.new()
	go_btn.add_theme_font_size_override("font_size", 20)
	go_btn.add_theme_color_override("font_color", Color("1a1405"))
	go_btn.add_theme_color_override("font_hover_color", Color("1a1405"))
	go_btn.add_theme_color_override("font_pressed_color", Color("1a1405"))
	go_btn.add_theme_stylebox_override("normal", _box(BRASS, BRASS, 0, 4))
	go_btn.add_theme_stylebox_override("hover", _box(Color("dcb85f"), BRASS, 0, 4))
	go_btn.add_theme_stylebox_override("pressed", _box(BRASS_D, BRASS_D, 0, 4))
	go_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go_btn.pressed.connect(_on_go)
	main.add_child(go_btn)

	msg = _label("", 16, DIM)
	main.add_child(msg)

	_load_level(0)


func _load_level(i: int) -> void:
	level = i
	is_solved = false
	var lv: Dictionary = LEVELS[i]
	slab.add_theme_stylebox_override("panel", _box(SLAB, BRASS_D, 2, 6))
	lvl_label.text = lv["name"]
	go_btn.text = "Turn the key"

	_clear(eq_box)
	for e in lv["eqs"]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 14)
		row.add_child(Glyph.new(e[0], 52))
		row.add_child(_label(e[1], 44, BRASS))
		row.add_child(Glyph.new(e[2], 52))
		row.add_child(_label("=", 44, BRASS))
		row.add_child(_label(str(e[3]), 44, INK))
		eq_box.add_child(row)

	_clear(dial_row)
	vals.clear()
	dial_labels.clear()
	var order: Array = lv["order"]
	for n in order.size():
		vals.append(0)
		dial_row.add_child(_make_dial(n, order[n]))


func _make_dial(n: int, kind: String) -> Control:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", _box(SLAB, BRASS_D, 1, 6))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)

	v.add_child(_arrow("▲", n, 1))

	var win := PanelContainer.new()
	win.custom_minimum_size = Vector2(0, 90)
	win.size_flags_vertical = Control.SIZE_EXPAND_FILL
	win.focus_mode = Control.FOCUS_ALL
	win.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	win.add_theme_stylebox_override("panel", _box(WELL, BRASS_D, 1, 4))
	win.gui_input.connect(_on_win_input.bind(n))
	var lab := _label("0", 60, INK)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win.add_child(lab)
	dial_labels.append(lab)
	v.add_child(win)

	v.add_child(_arrow("▼", n, -1))

	var gc := CenterContainer.new()
	gc.add_child(Glyph.new(kind, 36))
	v.add_child(gc)
	return p


func _arrow(txt: String, n: int, d: int) -> Button:
	var b := Button.new()
	b.text = txt
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", BRASS)
	b.add_theme_color_override("font_hover_color", Color("dcb85f"))
	b.pressed.connect(_turn.bind(n, d))
	return b


# ---------- input ----------
func _on_win_input(event: InputEvent, n: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_turn(n, 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_turn(n, -1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			(dial_row.get_child(n).get_child(0).get_child(1) as Control).grab_focus()
			drag_accum = 0.0
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		drag_accum -= event.relative.y   # drag up = higher number
		if absf(drag_accum) >= 22.0:
			_turn(n, 1 if drag_accum > 0 else -1)
			drag_accum = 0.0
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_UP:
			_turn(n, 1)
		elif event.keycode == KEY_DOWN:
			_turn(n, -1)
		elif event.keycode >= KEY_0 and event.keycode <= KEY_9:
			vals[n] = event.keycode - KEY_0
			_refresh(n)


func _turn(n: int, d: int) -> void:
	if is_solved:
		return
	vals[n] = posmod(vals[n] + d, 10)
	_refresh(n)


func _refresh(n: int) -> void:
	var l := dial_labels[n]
	l.text = str(vals[n])
	l.modulate.a = 0.0
	create_tween().tween_property(l, "modulate:a", 1.0, 0.15)


# ---------- check ----------
func _on_go() -> void:
	if is_solved:
		if level < LEVELS.size() - 1:
			_load_level(level + 1)
		return

	var lv: Dictionary = LEVELS[level]
	var order: Array = lv["order"]
	var ok := true
	for i in order.size():
		if vals[i] != lv["values"][order[i]]:
			ok = false

	if ok:
		is_solved = true
		slab.add_theme_stylebox_override("panel", _box(SLAB, TEAL, 2, 6))
		msg.add_theme_color_override("font_color", TEAL)
		var more := level < LEVELS.size() - 1
		msg.text = "The seal gives way. Another lies beneath." if more else "The seal gives way. The way is open."
		go_btn.text = "Next seal" if more else "Unlocked"
		solved.emit(level)
		if not more:
			all_solved.emit()
	else:
		msg.add_theme_color_override("font_color", BAD)
		msg.text = "The stone stays shut. Check each glyph again."
		var x := dial_row.position.x
		var t := create_tween()
		for off in [-8.0, 8.0, -5.0, 5.0, 0.0]:
			t.tween_property(dial_row, "position:x", x + off, 0.06)
