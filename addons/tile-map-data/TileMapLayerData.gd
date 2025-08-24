@tool
extends EditorPlugin

const META_STRING = "_TILE_MAP_DATA_"

var dock : Control
var button : Button
var tile_map_data : TileMapLayer
var tile_coords : Vector2i
var tile_data : TileData
var data_layer : Dictionary[Vector2i, Dictionary] = {}
var property_node_scene = preload("res://addons/tile-map-data/editor/tile_data_property.tscn")

func _enter_tree() -> void:
	await get_tree().process_frame
	dock = load("res://addons/tile-map-data/editor/Dock.tscn").instantiate()

	button = add_control_to_bottom_panel(dock, "Map Data")
	button.visible = false

func _exit_tree() -> void:
	remove_control_from_bottom_panel(dock)
	dock.queue_free()

func _make_visible(visible: bool) -> void:
	button.visible = visible

func _handles(object) -> bool:
	return object is TileMapLayer

func _edit(object: Object) -> void:
	if object is TileMapLayer:
		tile_map_data = object

func _forward_canvas_draw_over_viewport(viewport_control: Control) -> void:
	var viewport : SubViewport = EditorInterface.get_editor_viewport_2d()
	var transform : Transform2D = viewport.global_canvas_transform

	print(viewport, transform)

	if tile_map_data and tile_coords:
		viewport_control.draw_rect(
			Rect2(
				Vector2(
					(tile_map_data.tile_set.tile_size.x * transform.x[0]) * tile_coords.x,
					(tile_map_data.tile_set.tile_size.y * transform.y[1]) * tile_coords.y
				) + transform.origin,
				Vector2(tile_map_data.tile_set.tile_size * transform.x[0]),
			),
			Color.WHITE,
			false,
			4.0
		)

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.button_index == 1:
		tile_coords = tile_map_data.local_to_map(EditorInterface.get_editor_viewport_2d().get_mouse_position())

		_show_tile_form()

	return false

func _show_tile_form() -> void:
	var source = tile_map_data.tile_set.get_source(tile_map_data.get_cell_source_id(tile_coords)) as TileSetSource
	var tile_data : Dictionary[StringName, Dictionary]

	if source is TileSetAtlasSource:
		tile_data = get_tile_atlas_source(source)
	elif source is TileSetScenesCollectionSource:
		tile_data = get_scene_collection_source(source)
	else:
		push_error("Did not get a known TileSetSource type")

	render_tile_form(tile_data)


func get_tile_atlas_source(source: TileSetAtlasSource) -> Dictionary[StringName, Dictionary]:
	tile_data = tile_map_data.get_cell_tile_data(tile_coords)
	dock.find_child('TileMapDataText').text = "%s" % tile_data

	var tile_dictionary : Dictionary[StringName, Dictionary]

	# Loop through data sets
	for layer_idx in tile_map_data.tile_set.get_custom_data_layers_count():
		var data_layer_name : StringName = tile_map_data.tile_set.get_custom_data_layer_name(layer_idx)
		var data_layer_type = tile_map_data.tile_set.get_custom_data_layer_type(layer_idx)
		var data_layer_value = tile_data.get_custom_data(data_layer_name)
		tile_dictionary[data_layer_name] = {
			data_layer_type: data_layer_value if data_layer_value else null
		}

	return { 'TileData' : tile_dictionary }


func get_scene_collection_source(source: TileSetScenesCollectionSource) -> Dictionary[StringName, Dictionary]:
	var packed_scene : PackedScene = source.get_scene_tile_scene(tile_map_data.get_cell_tile(tile_coords))
	var state = packed_scene.get_state()
	var script = packed_scene.get_script()

	var node_dictionary : Dictionary[StringName, Dictionary]
	# Loop through every node in this tile if node has properties dig through them
	for idx in range(0, state.get_node_count() ):
		var node : PackedScene = state.get_node_instance(idx)

		if state.get_node_property_count(idx) > 0:
			var node_definition : Dictionary[StringName, Dictionary] = {}
			var node_name = state.get_node_name(idx)

			# Dig through each property in a node
			for propIdx in range(0, state.get_node_property_count(idx) ):
				var pname = state.get_node_property_name(idx, propIdx)
				var pvalue = state.get_node_property_value(idx, propIdx)
				var ptype = typeof(pvalue)
				if ptype == TYPE_OBJECT and is_instance_of(pvalue, GDScript):
					var properties = (pvalue as GDScript).get_script_property_list()
					for property in properties:
						if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE > 0:
							var property_definition : Dictionary[StringName, Dictionary]

							node_definition[property.name] = property
			# If there are any properties add this node to the tile def
			if node_definition.size() > 0:
				node_dictionary[node_name] = node_definition

	print(node_dictionary)

	return node_dictionary


#Get the value of the scene
func get_node_value(tile_coords, node, control):
	var source : TileSetSource = tile_map_data.tile_set.get_source(tile_map_data.get_cell_source_id(tile_coords)) as TileSetSource
	var packed_scene : PackedScene = source.get_scene_tile_scene(tile_map_data.get_cell_tile(tile_coords))
	var state = packed_scene.get_state()

	pass

#Overrides the value of
func set_node_value():
	pass

#Get the override value
func get_override_value(tile_coords, node, control) -> Variant:
	var metadata = tile_map_data.get_meta(META_STRING)
	if ! metadata.has(tile_coords):
		return

	if ! metadata[tile_coords].has(node):
		return

	if ! metadata[tile_coords][node].has(control):
		return

	return metadata[tile_coords][node][control]

#Set the override value
func set_override_value(tile_coords, node, control, value):
	pass

func render_tile_form(data: Dictionary[StringName, Dictionary]) -> void:
	for child in dock.find_child(&'PropertyContainer').get_children():
		child.queue_free()

	#Loops through Child nodes
	for node in data:
		var property_node = property_node_scene.instantiate()
		property_node.find_child(&'Label').text = node

		for label in data[node]:
			var property = data[node][label]
			var label_node = Label.new()
			label_node.text = property.name

			var control : Control

			match property.type:
				TYPE_BOOL:
					control = CheckBox.new()
				TYPE_INT:
					control = SpinBox.new()
				TYPE_FLOAT:
					control = SpinBox.new()
				_:
					control = Label.new()

			if control:
				property_node.find_child("GridContainer").add_child(label_node)
				property_node.find_child("GridContainer").add_child(control)

		dock.find_child('PropertyContainer').add_child(property_node)
