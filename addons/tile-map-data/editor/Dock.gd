@tool
extends Control

signal update_overlay

var undo_manager : EditorUndoRedoManager
var tileMapLayer : TileMapLayer

func _ready() -> void:
	%SelectTiles.icon = get_theme_icon("ToolSelect", "EditorIcons")
