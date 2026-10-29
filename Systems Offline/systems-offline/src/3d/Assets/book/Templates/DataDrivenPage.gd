class_name DataDrivenPage
extends BookPage

@export var page_data: SimpleBookPageData:
	set(val):
		page_data = val
		if is_node_ready():
			setup(page_data)

@onready var title_label: Label = get_node_or_null("%TitleLabel")
@onready var doc_id_label: Label = get_node_or_null("%DocIdLabel")
@onready var body_label: RichTextLabel = get_node_or_null("%BodyLabel")
@onready var image_rect: TextureRect = get_node_or_null("%ImageRect")
@onready var image_container: Control = get_node_or_null("%ImageContainer")
@onready var notes_box: Control = get_node_or_null("%NotesBox")
@onready var notes_label: RichTextLabel = get_node_or_null("%NotesLabel")

func _ready() -> void:
	super._ready()
	if page_data:
		setup(page_data)

func setup(data: SimpleBookPageData) -> void:
	if not data:
		return
	page_data = data
	if title_label:
		title_label.text = data.title
	if doc_id_label:
		doc_id_label.text = data.document_id
		doc_id_label.visible = not data.document_id.is_empty()
	if body_label:
		body_label.text = data.body
	if image_rect and image_container:
		if data.image:
			image_rect.texture = data.image
			image_container.visible = true
		else:
			image_container.visible = false
	if notes_box and notes_label:
		if not data.notes.is_empty():
			notes_label.text = data.notes
			notes_box.visible = true
		else:
			notes_box.visible = false
	set_page_number(data.page_number)
