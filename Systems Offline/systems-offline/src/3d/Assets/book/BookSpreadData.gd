class_name BookSpreadData
extends Resource

@export var section_name: String = ""
@export var left_page: PackedScene
@export var right_page: PackedScene

# Optional data-driven page resources (SimpleBookPageData)
@export var left_page_data: Resource
@export var right_page_data: Resource
