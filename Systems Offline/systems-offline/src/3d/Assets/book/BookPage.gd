class_name BookPage
extends Control

@export var paper_color: Color = Color("e8dcc8")
@export var page_number: int = 1:
	set(val):
		page_number = val
		_update_page_number()

@onready var background: ColorRect = get_node_or_null("Background")
@onready var page_number_label: Label = get_node_or_null("%PageNumber")

func _ready() -> void:
	if background:
		background.color = paper_color
	_update_page_number()

func set_page_number(num: int) -> void:
	page_number = num

func _update_page_number() -> void:
	if page_number_label:
		page_number_label.text = str(page_number)
