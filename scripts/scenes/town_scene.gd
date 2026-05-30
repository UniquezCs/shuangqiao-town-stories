extends Node2D

func get_map_layer(layer_name: String) -> TileMapLayer:
	var map_layers := get_node_or_null("MapLayers")
	if map_layers == null:
		return get_node_or_null(layer_name) as TileMapLayer
	return map_layers.get_node_or_null(layer_name) as TileMapLayer
