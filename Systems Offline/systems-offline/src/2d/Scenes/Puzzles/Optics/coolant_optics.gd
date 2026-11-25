extends Control

signal solved

const BOARD := Vector2(960, 595)
const CHAMBER := Rect2(55, 112, 850, 275)
const PLACEMENT := Rect2(82, 139, 796, 221)
const LEVEL_DIR := "res://src/2d/Scenes/Puzzles/Optics/levels"
const CAMPAIGN_LEVELS := [
	"res://src/2d/Scenes/Puzzles/Optics/levels/level1.json",
	"res://src/2d/Scenes/Puzzles/Optics/levels/level2.json",
	"res://src/2d/Scenes/Puzzles/Optics/levels/level3.json",
	"res://src/2d/Scenes/Puzzles/Optics/levels/level4.json",
]
const PROGRESS_PATH := "user://coolant_optics_progress.cfg"
const EXIT_TYPES := ["Red", "Green", "Blue", "Yellow", "Cyan", "Magenta"]
const EMITTER_TYPES := ["Red Emitter", "Green Emitter", "Blue Emitter", "Yellow Emitter", "Cyan Emitter", "Magenta Emitter"]
const OPTICS_TYPES := ["Emitter", "Prism", "Mirror", "Splitter", "Wall"]
const WHITE := 6
const SPLIT_ANGLE := PI / 4.0
# Each bit represents one additive light channel: red, green, or blue.
const LIGHT_CHANNELS := [0b001, 0b010, 0b100, 0b011, 0b110, 0b101, 0b111]
const COLORS := [Color("#ff686a"), Color("#79eca2"), Color("#6bbaff"),
	Color("#ffdf62"), Color("#5ae8ed"), Color("#f383ed"), Color("#eff8ff")]
const TITLE = preload("res://src/2d/Fonts/Systems-Offline (2).ttf")
const BODY = preload("res://src/2d/Fonts/MatixType/MatrixType-Regular.ttf")
const CYAN := Color(0, 0.8, 0.95, 0.85)

@export var campaign_enabled := false

var campaign_level := -1
var unlocked_count := 1
var completed_count := 0
var selecting_level := false
var level_menu: VBoxContainer
var level_buttons: Array[Button] = []
var next_button: Button

var pieces: Array[Dictionary] = []
var starting_pieces: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var lit := {}
var exit_channels: Dictionary[int, int] = {}
var editing := false
var complete := false
var selected := -1
var held := -1
var pending_type := ""
var grab_offset := Vector2.ZERO
var board_scale := 1.0
var board_offset := Vector2.ZERO
var level_name := "Coolant Optics"

@onready var bar: Control = $Interface
@onready var toolbar: HBoxContainer = $Interface/Toolbar
@onready var hotbar: VBoxContainer = $Interface/Hotbar
@onready var status: Label = $Interface/Status
@onready var dialog: FileDialog = $LevelFile

var remove_button: Button
var add_piece_kinds: Array[String] = []


func _ready() -> void:
	print(
		"[COOLANT] Debug build | scene=", scene_file_path,
		" main=", ProjectSettings.get_setting("application/run/main_scene"),
		" campaign_enabled=", campaign_enabled,
		" parent=", get_parent().name
	)

	resized.connect(_layout_board)
	for pair in [
		["RESET", _reset],
		["EDIT LEVEL", _edit_or_play],
		["LOAD LEVEL", _choose_load],
		["SAVE LEVEL", _choose_save],
		["NEW LEVEL", _new_level],
	]:
		_button(toolbar, pair[0], pair[1])

	_setup_editor_tools()
	dialog.file_selected.connect(_on_file_selected)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(LEVEL_DIR)
	)

	print("[COOLANT] Initializing built-in board before campaign setup")
	starting_pieces = [
		_piece("Emitter", Vector2(115, 238)),
		_piece("Prism", Vector2(338, 274), 15),
		_piece("Red", Vector2(810, 166)),
		_piece("Green", Vector2(810, 238)),
		_piece("Blue", Vector2(810, 310)),
	]

	_layout_board()
	_refresh_mode()
	_reset()

	if campaign_enabled or get_parent() == get_tree().root:
		_setup_campaign()

func _setup_campaign() -> void:
	var progress := ConfigFile.new()
	if progress.load(PROGRESS_PATH) == OK:
		completed_count = clampi(int(progress.get_value("campaign", "completed", 0)), 0, CAMPAIGN_LEVELS.size())
		unlocked_count = mini(completed_count + 1, CAMPAIGN_LEVELS.size())

	level_menu = VBoxContainer.new()
	level_menu.position = Vector2(305, 140)
	level_menu.custom_minimum_size.x = 350
	level_menu.add_theme_constant_override("separation", 8)
	bar.add_child(level_menu)
	for index in CAMPAIGN_LEVELS.size():
		level_buttons.append(_button(level_menu, "", _start_campaign_level.bind(index)))
	_button(level_menu, "LEVEL EDITOR", _open_editor)

	var navigation := HBoxContainer.new()
	navigation.position = Vector2(530, 25)
	bar.add_child(navigation)
	next_button = _button(navigation, "NEXT LEVEL", _next_level)
	_button(navigation, "LEVEL SELECT", _show_level_select)
	navigation.alignment = BoxContainer.ALIGNMENT_END
	navigation.custom_minimum_size.x = 375
	solved.connect(_on_campaign_solved)
	_show_level_select()


func _show_level_select() -> void:
	print("[COOLANT] Show level select | unlocked=", unlocked_count, " completed=", completed_count)
	_clear_selection()
	selecting_level = true
	campaign_level = -1
	level_menu.show()
	toolbar.hide()
	hotbar.hide()
	status.hide()
	next_button.get_parent().hide()
	for index in level_buttons.size():
		var button := level_buttons[index]
		button.disabled = index >= unlocked_count
		button.text = "LEVEL %d" % (index + 1)
		if button.disabled:
			button.text += "  /  LOCKED"
		elif index < completed_count:
			button.text += "  /  COMPLETE"
	level_buttons[mini(completed_count, unlocked_count - 1)].grab_focus()
	queue_redraw()


func _start_campaign_level(index: int) -> void:
	print("[COOLANT] Campaign level requested | index=", index, " unlocked=", unlocked_count)
	if index < 0 or index >= unlocked_count:
		print("[COOLANT] Request rejected: level locked or out of range")
		return
	var path: String = CAMPAIGN_LEVELS[index]
	if not _load_level(path):
		status.text = "%s (%s)" % [status.text, path.get_file()]
		status.show()
		return
	campaign_level = index
	editing = false
	_show_board()
	_reset()


func _open_editor() -> void:
	campaign_level = -1
	editing = true
	_show_board()
	_new_level()


func _show_board() -> void:
	selecting_level = false
	level_menu.hide()
	toolbar.show()
	status.show()
	next_button.get_parent().show()
	next_button.hide()
	_refresh_mode()
	grab_focus()


func _on_campaign_solved() -> void:
	print("[COOLANT] Solved signal | campaign index=", campaign_level, " board=", level_name)
	if campaign_level < 0:
		return
	if campaign_level + 1 > completed_count:
		completed_count = campaign_level + 1
		unlocked_count = mini(completed_count + 1, CAMPAIGN_LEVELS.size())
		var progress := ConfigFile.new()
		progress.set_value("campaign", "completed", completed_count)
		if progress.save(PROGRESS_PATH) != OK:
			push_warning("Could not save Coolant Optics campaign progress.")
	next_button.text = "NEXT LEVEL" if campaign_level + 1 < CAMPAIGN_LEVELS.size() else "FINISH"
	next_button.show()
	next_button.grab_focus()


func _next_level() -> void:
	print("[COOLANT] Next pressed | current index=", campaign_level)
	if campaign_level + 1 == CAMPAIGN_LEVELS.size():
		_show_level_select()
	else:
		_start_campaign_level(campaign_level + 1)


func _button(row: Container, label: String, action: Callable) -> Button:
	var control := Button.new()
	control.text = label
	control.pressed.connect(action)
	row.add_child(control)
	return control


func _layout_board() -> void:
	board_scale = minf(size.x / BOARD.x, size.y / BOARD.y)
	board_offset = (size - BOARD * board_scale) * 0.5
	bar.position = board_offset
	bar.scale = Vector2.ONE * board_scale
	queue_redraw()


func _piece(kind: String, position_on_board: Vector2, angle: float = 0.0) -> Dictionary:
	return {"kind": kind, "position": position_on_board, "angle": angle}


func _edit_or_play() -> void:
	if editing:
		starting_pieces = pieces.duplicate(true)
	else:
		pieces = starting_pieces.duplicate(true)
	editing = not editing
	complete = false
	_clear_selection()
	_refresh_mode()
	_update_board()


func _refresh_mode() -> void:
	toolbar.get_child(1).text = "PLAY TEST" if editing else "EDIT LEVEL"
	toolbar.get_child(1).visible = campaign_level < 0
	toolbar.get_child(2).visible = campaign_level < 0
	toolbar.get_child(3).visible = editing
	toolbar.get_child(4).visible = editing
	hotbar.visible = editing

	if not editing and remove_button != null:
		remove_button.set_pressed_no_signal(false)

	if next_button != null:
		var navigation := next_button.get_parent() as HBoxContainer
		navigation.position = Vector2(
			530, 401 if campaign_level >= 0 else 465
		)

func _clear_selection() -> void:
	selected = -1
	held = -1
	pending_type = ""


func _reset() -> void:
	print("[COOLANT] Reset | level=", level_name, " index=", campaign_level, " pieces=", starting_pieces.size())
	if next_button != null:
		next_button.hide()
	pieces = starting_pieces.duplicate(true)
	complete = false
	_clear_selection()
	_update_board()


func _new_level() -> void:
	level_name = "Untitled Level"
	starting_pieces.clear()
	_reset()


func _select_tool(kind: String) -> void:
	pending_type = kind
	selected = -1
	status.text = "Click in the chamber to place %s. Esc cancels." % kind


func _input(event: InputEvent) -> void:
	if held >= 0 and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_drop_piece()
		get_viewport().set_input_as_handled()


func _drop_piece() -> void:
	held = -1
	_update_board(true)


func _gui_input(event: InputEvent) -> void:
	if selecting_level or dialog.visible or board_scale <= 0:
		return

	if event is InputEventKey and event.pressed and editing:
		if event.keycode == KEY_ESCAPE:
			_clear_selection()
			_update_board()
		elif event.keycode == KEY_DELETE:
			_delete_piece(selected)
		return

	if not event is InputEventMouse:
		return

	var point := (get_local_mouse_position() - board_offset) / board_scale
	var hit := _pick_piece(point)

	if event is InputEventMouseMotion and held >= 0:
		pieces[held]["position"] = (point - grab_offset).clamp(
			PLACEMENT.position, PLACEMENT.end
		)
		_update_board()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_press_board(point, hit)
			MOUSE_BUTTON_RIGHT:
				if editing:
					_delete_piece(hit)
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				var index := held if held >= 0 else hit
				if _can_move(index):
					var step := 5.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -5.0
					pieces[index]["angle"] = float(pieces[index]["angle"]) + step
					_update_board()

	accept_event()
	
func _press_board(point: Vector2, hit: int) -> void:
	if editing and remove_button.button_pressed:
		if hit >= 0:
			_delete_piece(hit)
		status.text = "Click a piece to remove it."
		return

	if editing and not pending_type.is_empty() and PLACEMENT.has_point(point):
		if pieces.size() >= 60:
			status.text = "This level already has 60 pieces."
			return

		pieces.append(_piece(pending_type, point))
		selected = pieces.size() - 1
		pending_type = ""
		_update_board()
	elif _can_move(hit):
		grab_focus()
		held = hit
		selected = hit
		grab_offset = point - Vector2(pieces[hit]["position"])
		_update_board()

func _pick_piece(point: Vector2) -> int:
	for index in range(pieces.size() - 1, -1, -1):
		var part := pieces[index]
		var center: Vector2 = part["position"]
		match part["kind"]:
			"Prism":
				if Geometry2D.is_point_in_polygon(point, _triangle(part)):
					return index
			"Mirror", "Wall":
				var ends := _edge(part)
				if point.distance_to(Geometry2D.get_closest_point_to_segment(point, ends[0], ends[1])) < 10:
					return index
			_:
				if point.distance_to(center) < 18:
					return index
	return -1


func _can_move(index: int) -> bool:
	return index >= 0 and (editing or pieces[index]["kind"] in ["Prism", "Mirror", "Splitter"])


func _delete_piece(index: int) -> void:
	if index >= 0 and index < pieces.size():
		pieces.remove_at(index)
		_clear_selection()
		_update_board()


func _edge(part: Dictionary) -> PackedVector2Array:
	var center: Vector2 = part["position"]
	var extent := 33.0 if part["kind"] == "Wall" else 24.0
	var axis := Vector2.RIGHT.rotated(deg_to_rad(part["angle"])) * extent
	return PackedVector2Array([center - axis, center + axis])


func _triangle(part: Dictionary) -> PackedVector2Array:
	var center: Vector2 = part["position"]
	var shape := PackedVector2Array()
	for corner in [Vector2(0, -23), Vector2(22, 16), Vector2(-22, 16)]:
		shape.append(center + corner.rotated(deg_to_rad(part["angle"])))
	return shape


func _update_board(piece_dropped: bool = false) -> void:
	beams.clear()
	lit.clear()
	exit_channels.clear()

	var receiver_count := 0
	for index in pieces.size():
		var part := pieces[index]
		var emitter_color := _emitter_color(part["kind"])
		if emitter_color >= 0 and beams.size() < 260:
			_trace(
				part["position"],
				Vector2.RIGHT.rotated(deg_to_rad(part["angle"])),
				emitter_color,
				index,
				0
			)
		elif part["kind"] in EXIT_TYPES:
			receiver_count += 1

	for index in exit_channels:
		var exit_color := EXIT_TYPES.find(pieces[index]["kind"])
		if exit_channels[index] == LIGHT_CHANNELS[exit_color]:
			lit[index] = true

	var aligned := receiver_count > 0 and lit.size() == receiver_count
	if piece_dropped:
		print(
			"[COOLANT] Drop | level=", level_name,
			" receivers=", lit.size(), "/", receiver_count,
			" aligned=", aligned
		)

	var was_complete := complete
	complete = aligned and held < 0 and not editing
	if complete and not was_complete:
		solved.emit()

	if next_button != null:
		next_button.visible = campaign_level >= 0 and complete

	status.text = "%s  /  %d of %d receivers lit" % [
		level_name, lit.size(), receiver_count
	]
	if complete:
		status.text = "CALIBRATED  /  COOLANT PUMP ONLINE"

	queue_redraw()


func _trace(origin: Vector2, direction: Vector2, color_index: int, skip: int, depth: int) -> void:
	if depth >= 12 or beams.size() >= 260:
		return

	var finish := origin + direction * 1800.0
	var corners := [
		CHAMBER.position,
		Vector2(CHAMBER.end.x, CHAMBER.position.y),
		CHAMBER.end,
		Vector2(CHAMBER.position.x, CHAMBER.end.y),
	]

	for edge_index in 4:
		var boundary: Variant = Geometry2D.segment_intersects_segment(
			origin, finish, corners[edge_index], corners[(edge_index + 1) % 4]
		)
		if boundary != null:
			finish = boundary

	var hit := -1
	for index in pieces.size():
		if index == skip or _emitter_color(pieces[index]["kind"]) >= 0:
			continue
		var part := pieces[index]
		var point: Variant = _intersection(origin, finish, part)
		if point != null and origin.distance_squared_to(point) > 0.01:
			finish = point
			hit = index

	beams.append({"from": origin, "to": finish, "color": color_index})
	if hit < 0:
		return

	var part := pieces[hit]
	match part["kind"]:
		"Prism":
			var center: Vector2 = part["position"]
			var steering := sin(deg_to_rad(part["angle"])) * 0.5
			if color_index == WHITE:
				for channel in 3:
					_trace(
						center, direction.rotated(steering + (channel - 1) * 0.18),
						channel, hit, depth + 1
					)
			else:
				_trace(center, direction.rotated(steering), color_index, hit, depth + 1)
		"Splitter":
			var turn := deg_to_rad(wrapf(float(part["angle"]), -180.0, 180.0))
			_trace(finish, direction, color_index, hit, depth + 1)
			if not is_zero_approx(turn):
				_trace(finish, direction.rotated(turn), color_index, hit, depth + 1)
		"Mirror":
			var normal := Vector2.UP.rotated(deg_to_rad(part["angle"]))
			_trace(finish, direction.bounce(normal), color_index, hit, depth + 1)
		_:
			if part["kind"] in EXIT_TYPES:
				exit_channels[hit] = int(exit_channels.get(hit, 0)) | LIGHT_CHANNELS[color_index]

func _intersection(origin: Vector2, finish: Vector2, part: Dictionary) -> Variant:
	if part["kind"] in ["Wall", "Mirror"]:
		var ends := _edge(part)
		return Geometry2D.segment_intersects_segment(origin, finish, ends[0], ends[1])
	if part["kind"] == "Prism":
		var outline := _triangle(part)
		var nearest: Variant = null
		for index in 3:
			var point: Variant = Geometry2D.segment_intersects_segment(origin, finish, outline[index], outline[(index + 1) % 3])
			if point != null and (nearest == null or origin.distance_squared_to(point) < origin.distance_squared_to(nearest)):
				nearest = point
		return nearest
	var center: Vector2 = part["position"]
	var closest := Geometry2D.get_closest_point_to_segment(center, origin, finish)
	if closest.distance_to(center) < 13.0:
		return closest
	return null


func _choose_save() -> void:
	var folder := ProjectSettings.globalize_path(LEVEL_DIR)
	var error := DirAccess.make_dir_recursive_absolute(folder)
	if error != OK:
		status.text = "Could not create the level folder: " + error_string(error)
		return

	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.current_dir = folder
	dialog.current_file = level_name.validate_filename() + ".json"
	dialog.popup_centered_ratio(0.75)


func _choose_load() -> void:
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.current_dir = ProjectSettings.globalize_path(LEVEL_DIR)
	dialog.current_file = ""
	dialog.popup_centered_ratio(0.75)


func _on_file_selected(path: String) -> void:
	print("[COOLANT] File dialog selection | path=", path, " mode=", dialog.file_mode)
	if dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		_save_level(path)
	elif _load_level(path):
		_reset()


func _save_level(path: String) -> void:
	if path.get_extension().to_lower() != "json":
		status.text = "Use a .json filename for the level."
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		status.text = "Could not open the level file for writing."
		return
	var name_to_save := path.get_file().get_basename()
	var entries: Array[Dictionary] = []
	for part in pieces:
		var point: Vector2 = part["position"]
		entries.append({"kind": part["kind"], "x": point.x, "y": point.y, "angle": part["angle"]})
	file.store_string(JSON.stringify({"version": 1, "name": name_to_save, "pieces": entries}, "\t"))
	file.flush()
	if file.get_error() != OK:
		status.text = "Could not finish writing the level file."
		return
	level_name = name_to_save
	starting_pieces = pieces.duplicate(true)
	status.text = "Saved " + level_name


func _load_level(path: String) -> bool:
	print("[COOLANT] Load requested | path=", path, " exists=", FileAccess.file_exists(path))
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 65536:
		print("[COOLANT] Read failed | open error=", FileAccess.get_open_error(), " size=", file.get_length() if file != null else -1)
		status.text = "Could not read the level file."
		return false
	print("[COOLANT] File opened | bytes=", file.get_length())
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK:
		print("[COOLANT] JSON parse error | line=", json.get_error_line(), " message=", json.get_error_message())
	var data: Variant = json.data if parse_error == OK else null
	if not data is Dictionary or data.get("version") != 1 or not data.get("pieces") is Array or data["pieces"].size() > 60:
		print("[COOLANT] Invalid level structure | type=", type_string(typeof(data)))
		status.text = "This is not a valid Coolant Optics level."
		return false
	var loaded: Array[Dictionary] = []
	for entry in data["pieces"]:
		if not _valid_entry(entry):
			print("[COOLANT] Invalid piece at index ", loaded.size(), ": ", entry)
			status.text = "The level contains an invalid piece."
			return false
		var point := Vector2(entry["x"], entry["y"]).clamp(PLACEMENT.position, PLACEMENT.end)
		loaded.append(_piece(entry["kind"], point, wrapf(entry["angle"], -180.0, 180.0)))
	level_name = str(data.get("name", path.get_file().get_basename())).left(60)
	starting_pieces = loaded
	print("[COOLANT] JSON loaded | path=", path, " name=", level_name, " count=", loaded.size())
	for index in loaded.size():
		print("[COOLANT] Piece ", index, " | ", loaded[index])
	return true


func _valid_entry(entry: Variant) -> bool:
	if not entry is Dictionary or entry.get("kind") not in OPTICS_TYPES + EXIT_TYPES + EMITTER_TYPES:
		return false
	for key in ["x", "y", "angle"]:
		if typeof(entry.get(key)) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(entry[key])):
			return false
	return true


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0.04, 0.09))
	draw_set_transform(board_offset, 0.0, Vector2.ONE * board_scale)
	if selecting_level:
		draw_string(TITLE, Vector2(0, 90), "SELECT LEVEL", HORIZONTAL_ALIGNMENT_CENTER, int(BOARD.x), 36, Color(0.96, 0.98, 1))
		return
	draw_rect(CHAMBER, Color(0.03, 0.06, 0.11, 0.94))
	draw_rect(CHAMBER, CYAN, false, 1.0)
	var title := "LEVEL EDITOR" if editing else "COOLANT OPTICS"
	var help := "." if editing else "."
	draw_string(TITLE, Vector2(55, 55), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(0.96, 0.98, 1))
	draw_string(BODY, Vector2(55, 88), help, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.8, 0.9))
	for beam in beams:
		var tint: Color = COLORS[beam["color"]]
		draw_line(beam["from"], beam["to"], Color(tint, 0.18), 8.0, true)
		draw_line(beam["from"], beam["to"], tint, 2.0, true)
	for index in pieces.size():
		_draw_piece(index)


func _emitter_color(kind: String) -> int:
	return WHITE if kind == "Emitter" else EMITTER_TYPES.find(kind)


func _draw_piece(index: int) -> void:
	var part := pieces[index]
	var center: Vector2 = part["position"]
	var kind: String = part["kind"]
	if selected == index:
		draw_arc(center, 27, 0, TAU, 32, CYAN, 1.0, true)
	var emitter_color := _emitter_color(kind)
	if emitter_color >= 0:
		var direction := Vector2.RIGHT.rotated(deg_to_rad(part["angle"]))
		var tint: Color = COLORS[emitter_color]
		draw_circle(center, 15, Color("#174367"))
		draw_arc(center, 15, 0, TAU, 32, tint, 2.0, true)
		draw_line(center, center + direction * 19, tint, 4.0, true)
		return
	match kind:
		"Prism":
			var outline := _triangle(part)
			draw_colored_polygon(outline, Color("#568a9e"))
			outline.append(outline[0])
			draw_polyline(outline, Color("#ecfbff"), 2.0, true)
		"Splitter":
			draw_circle(center, 13, Color("#174367"))
			draw_arc(center, 13, 0, TAU, 32, CYAN, 2.0, true)
			var rotation_angle := deg_to_rad(part["angle"])
			for arm in [Vector2(-8, 0), Vector2(7, -7), Vector2(7, 7)]:
				draw_line(center, center + arm.rotated(rotation_angle), Color.WHITE, 2.0, true)
		"Mirror", "Wall":
			var ends := _edge(part)
			draw_line(ends[0], ends[1], Color("#b9e9ff") if kind == "Mirror" else Color("#586678"), 5.0, true)
		_:
			var tint: Color = COLORS[EXIT_TYPES.find(kind)]
			draw_circle(center, 13, tint if lit.has(index) else Color("#162631"))
			draw_arc(center, 13, 0, TAU, 32, tint, 2.0, true)
			draw_string(BODY, center + Vector2(-4, 5), kind.left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				Color("#08121b") if lit.has(index) else tint)
				
func _setup_editor_tools() -> void:
	hotbar.position = Vector2(55, 465)

	var tools: HBoxContainer = $Interface/Hotbar/Optics
	tools.add_theme_constant_override("separation", 8)
	$Interface/Hotbar/Emitters.hide()
	$Interface/Hotbar/Exits.hide()

	var add_button := MenuButton.new()
	add_button.text = "ADD ▾"
	tools.add_child(add_button)

	var menu := add_button.get_popup()
	for kind in OPTICS_TYPES + EMITTER_TYPES + EXIT_TYPES:
		var label: String = kind
		if kind == "Emitter":
			label = "White Emitter"
		elif kind in EXIT_TYPES:
			label += " Exit"

		var item_id := add_piece_kinds.size()
		add_piece_kinds.append(kind)
		menu.add_icon_item(_piece_menu_icon(kind), label, item_id)

	menu.id_pressed.connect(_on_add_piece_selected)

	remove_button = Button.new()
	remove_button.text = "REMOVE"
	remove_button.toggle_mode = true
	remove_button.toggled.connect(_on_remove_toggled)
	tools.add_child(remove_button)


func _on_add_piece_selected(item_id: int) -> void:
	remove_button.set_pressed_no_signal(false)
	_clear_selection()
	_select_tool(add_piece_kinds[item_id])


func _on_remove_toggled(active: bool) -> void:
	_clear_selection()
	_update_board()
	if active:
		status.text = "Click a piece to remove it."
func _piece_menu_icon(kind: String) -> Texture2D:
	var icon := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	var emitter_color := _emitter_color(kind)
	var exit_color := EXIT_TYPES.find(kind)

	for y in range(16):
		for x in range(16):
			var px := x - 8
			var py := y - 8
			var distance_squared := px * px + py * py

			if emitter_color >= 0:
				if distance_squared <= 25 or (abs(py) <= 1 and px >= 0 and px <= 7):
					icon.set_pixel(x, y, COLORS[emitter_color])
			elif exit_color >= 0:
				if distance_squared >= 16 and distance_squared <= 36:
					icon.set_pixel(x, y, COLORS[exit_color])
			else:
				match kind:
					"Prism":
						if py >= -5 and py <= 4 and abs(px) * 2 <= py + 5:
							icon.set_pixel(x, y, Color("#b9e9ff"))
					"Mirror":
						if abs(px) <= 5 and abs(px + py) <= 1:
							icon.set_pixel(x, y, Color("#b9e9ff"))
					"Splitter":
						if abs(px) <= 5 and (
							(px <= 0 and abs(py) <= 1)
							or (px >= 0 and abs(abs(py) - px) <= 1)
						):
							icon.set_pixel(x, y, CYAN)
					"Wall":
						if abs(px) <= 5 and abs(py) <= 2:
							icon.set_pixel(x, y, Color("#a5b6c7"))

	return ImageTexture.create_from_image(icon)
