class_name BookMenu
extends Control

signal close_requested

@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var page_content_container: Control = $PageOverlay/PagesContainer
@onready var left_page: PanelContainer = $PageOverlay/PagesContainer/LeftPage
@onready var right_page: PanelContainer = $PageOverlay/PagesContainer/RightPage

@onready var left_title: Label = $PageOverlay/PagesContainer/LeftPage/Margin/VBox/TitleLabel
@onready var left_body: RichTextLabel = $PageOverlay/PagesContainer/LeftPage/Margin/VBox/BodyLabel
@onready var left_page_num: Label = $PageOverlay/PagesContainer/LeftPage/Margin/VBox/BottomRow/PageNumLabel
@onready var right_title: Label = $PageOverlay/PagesContainer/RightPage/Margin/VBox/TitleLabel
@onready var right_body: RichTextLabel = $PageOverlay/PagesContainer/RightPage/Margin/VBox/BodyLabel
@onready var right_page_num: Label = $PageOverlay/PagesContainer/RightPage/Margin/VBox/BottomRow/PageNumLabel

@onready var left_corner_btn: Button = $PageOverlay/PagesContainer/LeftPage/Margin/VBox/BottomRow/LeftCornerBtn
@onready var right_corner_btn: Button = $PageOverlay/PagesContainer/RightPage/Margin/VBox/BottomRow/RightCornerBtn

@onready var tab_logs: Button = $PageOverlay/TopContainer/BookmarkContainer/TabLogs
@onready var tab_research: Button = $PageOverlay/TopContainer/BookmarkContainer/TabResearch
@onready var tab_maintenance: Button = $PageOverlay/TopContainer/BookmarkContainer/TabMaintenance
@onready var tab_notes: Button = $PageOverlay/TopContainer/BookmarkContainer/TabNotes
@onready var close_button: Button = $PageOverlay/TopContainer/CloseButton

var current_spread: int = 0
var is_turning_page: bool = false
var _turn_tween: Tween

const SPREADS = [
	{
		"section": 0,
		"section_name": "Logs",
		"left_title": "FACILITY LOG // SECTION 01",
		"left_body": "[b]SECURITY INCIDENT REPORT #8812[/b]\n[color=#8fa4b8]Timestamp: Cycle 409 // Sector 1[/color]\n\nAt 03:40 hours, automated telemetry detected uncommanded power reroutes across primary relay corridors. Sub-station 4 unresponsive to remote diagnostics.\n\nTechnician Valen dispatched to investigate manual conduit junction. Keypad access covers locked down per containment protocol Omega-3.\n\n[i]'If the relays continue cycling without cooling loops engaged, the blast doors will seal automatically.'[/i]",
		"left_page": "1",
		"right_title": "FACILITY LOG // SECTION 01",
		"right_body": "[b]LOG ENTRY // 042-B[/b]\n[color=#8fa4b8]Timestamp: Cycle 411 // Sector 1[/color]\n\nPower drain traced to the central comms relay array. Secondary elevators held on sub-level 1.\n\nAccess codes for storage room crates confirmed updated: personnel must verify local index markers before inputting keypad sequence 2-9-4-7.\n\nPhysical key access required to release touchscreen lockplate. Key remains logged in tutorial key rack.",
		"right_page": "2"
	},
	{
		"section": 1,
		"section_name": "Research",
		"left_title": "RESEARCH LAB // ANOMALIES",
		"left_body": "[b]PROJECT RESONANCE: REPORT A[/b]\n[color=#8fa4b8]Classification: Level 3 Classified[/color]\n\nCore sample telemetry reveals localized gravitational variance under high-frequency excitation. When acoustic nodes trigger at 440 Hz, mass-displacement indicators invert.\n\nPreliminary tests on organic matter deferred pending stabilization of containment bulkheads.",
		"left_page": "3",
		"right_title": "RESEARCH LAB // ANOMALIES",
		"right_body": "[b]SPECTRAL DEVIATION NOTE[/b]\n[color=#8fa4b8]Lead Researcher Dr. K. Aris[/color]\n\nThe alien script uncovered on bulkhead placards matches transmission bursts captured by deep-space array Kitefin.\n\nAutomated translation matrices remain inconclusive. Visual recognition apparatus suggests symbolic logic tied to optical triangulation.",
		"right_page": "4d4"
	},
	{
		"section": 2,
		"section_name": "Maintenance",
		"left_title": "MAINTENANCE DIRECTIVE",
		"left_body": "[b]WORK ORDER #1089-C[/b]\n[color=#8fa4b8]Facility Engineering Department[/color]\n\nScheduled maintenance on pneumatic sliding doors overdue by 72 cycles. Magnetic locks drawing 140% nominal current.\n\nHydraulic lift platform comms require manual lubrication. Do not bypass security interlocks without lead engineer signoff.",
		"left_page": "PAGE 5",
		"right_title": "MAINTENANCE DIRECTIVE",
		"right_body": "[b]CRATE LOCKING MECHANISM SPEC[/b]\n[color=#8fa4b8]Revision 4.2 Standard[/color]\n\nStorage container lids utilize mechanical counterweight servos. In the event of primary power loss, lids can be manually slid along the guide rails.\n\nInspect inside interior compartment floor for stencil identification markings.",
		"right_page": "PAGE 6"
	},
	{
		"section": 3,
		"section_name": "Notes",
		"left_title": "PERSONAL MEMORANDUM",
		"left_body": "[b]NOTE TO SELF[/b]\n[color=#8fa4b8]Shift Supervisor Mark[/color]\n\nRemember to return the brass key to the rack once the keypad enclosure is unlocked. If left on the console, the maintenance crew will log a safety violation.\n\nThe combination hasn't changed: check the 4 crates scattered across the shelves.",
		"left_page": "PAGE 7",
		"right_title": "EVACUATION PROTOCOL",
		"right_body": "[b]EMERGENCY STATION PROCEDURES[/b]\n[color=#8fa4b8]Facility Safety Division[/color]\n\nIn case of full systems offline status:\n1. Proceed to nearest illuminated exit.\n2. Secure facility logbook for incident review.\n3. Verify communications terminal status before entering elevator shaft.\n\n[i]'Stay calm. The facility failsafe systems operate independently of central AI.'[/i]",
		"right_page": "PAGE 8"
	}
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if sub_viewport:
		sub_viewport.process_mode = Node.PROCESS_MODE_ALWAYS

	# Prevent buttons from stealing keyboard focus so ESC / TAB / arrow keys always work
	var buttons: Array[Button] = [
		left_corner_btn, right_corner_btn,
		tab_logs, tab_research, tab_maintenance, tab_notes, close_button
	]
	for btn in buttons:
		if btn:
			btn.focus_mode = Control.FOCUS_NONE
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Connect buttons
	left_corner_btn.pressed.connect(prev_page)
	right_corner_btn.pressed.connect(next_page)

	tab_logs.pressed.connect(func(): go_to_section(0))
	tab_research.pressed.connect(func(): go_to_section(1))
	tab_maintenance.pressed.connect(func(): go_to_section(2))
	tab_notes.pressed.connect(func(): go_to_section(3))

	close_button.pressed.connect(func(): close_requested.emit())

	# Initialise page content
	_apply_spread_content(current_spread)
	_update_nav_buttons()
	_update_bookmark_tabs()


func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED:
		return	
	if not is_node_ready():
		return	
	if not visible:
		return	
	_reset_page_visuals()
	_apply_spread_content(current_spread)
	_update_nav_buttons()
	_update_bookmark_tabs()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		close_requested.emit()
	elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_LEFT):
		get_viewport().set_input_as_handled()
		prev_page()
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_RIGHT):
		get_viewport().set_input_as_handled()
		next_page()


func go_to_section(section_idx: int) -> void:
	for i in range(SPREADS.size()):
		if SPREADS[i]["section"] == section_idx:
			go_to_spread(i)
			return


func next_page() -> void:
	if current_spread < SPREADS.size() - 1:
		go_to_spread(current_spread + 1)


func prev_page() -> void:
	if current_spread > 0:
		go_to_spread(current_spread - 1)


func go_to_spread(index: int) -> void:
	if index < 0 or index >= SPREADS.size() or (index == current_spread and not is_turning_page):
		return
	if is_turning_page:
		return

	var forward: bool = index > current_spread
	is_turning_page = true

	# Anchor page pivots to the center spine
	left_page.pivot_offset = Vector2(left_page.size.x, left_page.size.y * 0.5)
	right_page.pivot_offset = Vector2(0.0, right_page.size.y * 0.5)

	var flip_duration: float = 0.16
	var lift_color := Color(0.65, 0.7, 0.8, 1.0)
	var lift_scale_y: float = 0.97

	if _turn_tween and _turn_tween.is_valid():
		_turn_tween.kill()

	_turn_tween = create_tween()
	_turn_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_turn_tween.set_trans(Tween.TRANS_QUAD)

	if forward:
		# First half: Right page folds inward toward the spine
		_turn_tween.set_ease(Tween.EASE_IN)
		_turn_tween.parallel().tween_property(right_page, "scale:x", 0.0, flip_duration)
		_turn_tween.parallel().tween_property(right_page, "scale:y", lift_scale_y, flip_duration)
		_turn_tween.parallel().tween_property(right_page, "modulate", lift_color, flip_duration)

		await _turn_tween.finished

		# Swap spread content at the spine
		current_spread = index
		_apply_spread_content(current_spread)
		_update_nav_buttons()
		_update_bookmark_tabs()

		# Reset right page, prepare left page to unfold from the spine
		right_page.scale = Vector2.ONE
		right_page.modulate = Color.WHITE

		left_page.pivot_offset = Vector2(left_page.size.x, left_page.size.y * 0.5)
		left_page.scale = Vector2(0.0, lift_scale_y)
		left_page.modulate = lift_color

		_turn_tween = create_tween()
		_turn_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_turn_tween.set_trans(Tween.TRANS_QUAD)
		_turn_tween.set_ease(Tween.EASE_OUT)

		_turn_tween.parallel().tween_property(left_page, "scale:x", 1.0, flip_duration)
		_turn_tween.parallel().tween_property(left_page, "scale:y", 1.0, flip_duration)
		_turn_tween.parallel().tween_property(left_page, "modulate", Color.WHITE, flip_duration)

		await _turn_tween.finished

		left_page.scale = Vector2.ONE
		left_page.modulate = Color.WHITE
	else:
		# First half: Left page folds inward toward the spine
		_turn_tween.set_ease(Tween.EASE_IN)
		_turn_tween.parallel().tween_property(left_page, "scale:x", 0.0, flip_duration)
		_turn_tween.parallel().tween_property(left_page, "scale:y", lift_scale_y, flip_duration)
		_turn_tween.parallel().tween_property(left_page, "modulate", lift_color, flip_duration)

		await _turn_tween.finished

		# Swap spread content at the spine
		current_spread = index
		_apply_spread_content(current_spread)
		_update_nav_buttons()
		_update_bookmark_tabs()

		# Reset left page, prepare right page to unfold from the spine
		left_page.scale = Vector2.ONE
		left_page.modulate = Color.WHITE

		right_page.pivot_offset = Vector2(0.0, right_page.size.y * 0.5)
		right_page.scale = Vector2(0.0, lift_scale_y)
		right_page.modulate = lift_color

		_turn_tween = create_tween()
		_turn_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_turn_tween.set_trans(Tween.TRANS_QUAD)
		_turn_tween.set_ease(Tween.EASE_OUT)

		_turn_tween.parallel().tween_property(right_page, "scale:x", 1.0, flip_duration)
		_turn_tween.parallel().tween_property(right_page, "scale:y", 1.0, flip_duration)
		_turn_tween.parallel().tween_property(right_page, "modulate", Color.WHITE, flip_duration)

		await _turn_tween.finished

		right_page.scale = Vector2.ONE
		right_page.modulate = Color.WHITE

	is_turning_page = false


func _reset_page_visuals() -> void:
	is_turning_page = false
	if _turn_tween and _turn_tween.is_valid():
		_turn_tween.kill()
	if left_page:
		left_page.scale = Vector2.ONE
		left_page.modulate = Color.WHITE
	if right_page:
		right_page.scale = Vector2.ONE
		right_page.modulate = Color.WHITE


func _apply_spread_content(idx: int) -> void:
	var data = SPREADS[idx]
	left_title.text = data["left_title"]
	left_body.text = data["left_body"]
	left_page_num.text = data["left_page"]

	right_title.text = data["right_title"]
	right_body.text = data["right_body"]
	right_page_num.text = data["right_page"]


func _update_nav_buttons() -> void:
	left_corner_btn.disabled = (current_spread == 0)
	right_corner_btn.disabled = (current_spread == SPREADS.size() - 1)


func _update_bookmark_tabs() -> void:
	var active_section = SPREADS[current_spread]["section"]
	var tabs = [tab_logs, tab_research, tab_maintenance, tab_notes]

	for i in range(tabs.size()):
		var tab: Button = tabs[i]
		if i == active_section:
			tab.modulate = Color(1.2, 1.1, 0.7, 1.0) # Highlight active tab
		else:
			tab.modulate = Color(0.7, 0.75, 0.85, 0.8)
