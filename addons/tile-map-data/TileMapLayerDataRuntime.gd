extends Node

func _enter_tree() -> void:
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(_node : Node) -> void:
	if is_instance_of(_node, TileMapLayer) and _node.has_meta(TileMapDataLayer.META_STRING):
		_node.ready.connect(TileMapDataLayer._apply_config.bind(_node))
