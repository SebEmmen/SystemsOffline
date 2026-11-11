extends Control

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
var can_skip: bool = false

func _ready() -> void:
	video_player.finished.connect(_on_video_finished)
	video_player.play()
	
	# Small buffer to prevent accidental input carry-over from the main menu click
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(func(): can_skip = true)

func _unhandled_input(event: InputEvent) -> void:
	if not can_skip:
		return
		
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		_transition_to_game()

func _on_video_finished() -> void:
	_transition_to_game()

func _transition_to_game() -> void:
	if get_tree() != null:
		# Call SaveManager to transition to Room1 and create the initial save file
		SaveManager.finish_cutscene()
