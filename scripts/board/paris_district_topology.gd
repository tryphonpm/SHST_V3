## First "real" multi-street board — a simplified Paris district with
## 4 streets forming a rectangle, 2 horizontal and 2 vertical.
##
## Layout (grid cells, each 96×96 px):
##
##   Row 0:  riv_e_0 ─── riv_e_1 ─── … ─── riv_e_7   Rivoli even (→)
##   Row 1:  riv_o_7 ←── riv_o_6 ←── … ←── riv_o_0   Rivoli odd  (←)
##
##   Col 0:  cas_e_0   cas_e_1   cas_e_2   cas_e_3     Castiglione even (↓)
##   Col 1:  cas_o_3   cas_o_2   cas_o_1   cas_o_0     Castiglione odd  (↑)
##
##   Col 7:  mar_e_0   mar_e_1   mar_e_2   mar_e_3     Marché even (↓)
##   Col 6:  mar_o_3   mar_o_2   mar_o_1   mar_o_0     Marché odd  (↑)
##
##   Row 6:  sth_e_0 ─── sth_e_1 ─── … ─── sth_e_7   Saint-Honoré even (→)
##   Row 7:  sth_o_7 ←── sth_o_6 ←── … ←── sth_o_0   Saint-Honoré odd  (←)
##
## Vertical streets span rows 2-5 (between the horizontal streets).
## Building interior fills the space between the 4 streets.
##
## 48 street nodes + 8 street-end Intersection nodes (auto-generated).
## 6 shops placed on specified nodes.
##
## This is still simplified: no diagonal streets, no one-way
## restrictions, no tram/metro.
##
## TODO: Diagonal streets (Rue des Pyramides crossing at 45°)
## TODO: One-way restrictions
## TODO: Tram/metro transfer points
class_name ParisDistrictTopology
extends BoardTopology

const RIVOLI      := &"rue_de_rivoli"
const SAINT_HONORE := &"rue_saint_honore"
const CASTIGLIONE := &"rue_castiglione"
const MARCHE      := &"rue_marche"

const H_CELLS := 8
const V_CELLS := 4
const CS := 96.0

const RIVOLI_EVEN_Y := 0.0
const RIVOLI_ODD_Y  := CS
const V_START_ROW   := 2
const V_END_ROW     := 5
const STH_EVEN_Y    := 6.0 * CS
const STH_ODD_Y     := 7.0 * CS

const CAST_EVEN_X := 0.0
const CAST_ODD_X  := CS
const MARCH_EVEN_X := 7.0 * CS
const MARCH_ODD_X  := 6.0 * CS

## Shop placements: { node_id: shop_id }
const SHOP_MAP: Dictionary = {
	&"riv_e_3": &"bakery",
	&"riv_o_4": &"butcher",
	&"sth_e_2": &"cheese_shop",
	&"cas_o_1": &"newsagent",
	&"mar_e_2": &"brasserie",
	&"sth_o_6": &"pharmacy",
}

## Default save path for the canonical Paris district graph.
const SAVE_PATH := "res://data/boards/paris_district_v1.tres"

# ─────────────────────────────────────────────────────────────
#  BoardTopology override
# ─────────────────────────────────────────────────────────────

## Build the graph and save it as a .tres resource.  Returns the
## graph on success, null on save failure.
func build_and_save(
	path: String = SAVE_PATH, run_verify: bool = true
) -> BoardGraph:
	var graph := build_graph()
	if graph == null:
		return null

	if run_verify:
		var issues := graph.verify_integrity()
		if not issues.is_empty():
			for issue in issues:
				push_warning("ParisDistrictTopology: %s" % issue)

	var err := graph.save_to_file(path)
	if err != OK:
		push_error(
			"ParisDistrictTopology: save failed (error %d)" % err
		)
		return null

	if run_verify:
		var rt_issues := BoardGraph.verify_round_trip(graph)
		if not rt_issues.is_empty():
			push_warning(
				"ParisDistrictTopology: round-trip had %d issues"
				% rt_issues.size()
			)

	return graph

func build_graph() -> BoardGraph:
	var graph := BoardGraph.new()
	var display := 1

	display = _add_h_street(graph, RIVOLI, "riv",
		RIVOLI_EVEN_Y, RIVOLI_ODD_Y, display)
	display = _add_h_street(graph, SAINT_HONORE, "sth",
		STH_EVEN_Y, STH_ODD_Y, display)
	display = _add_v_street(graph, CASTIGLIONE, "cas",
		CAST_EVEN_X, CAST_ODD_X, display)
	display = _add_v_street(graph, MARCHE, "mar",
		MARCH_EVEN_X, MARCH_ODD_X, display)

	_build_streets(graph)
	_wire_intersections(graph)

	graph.start_node_id = &"riv_e_0"

	var pad := GameConfig.BUILDING_INNER_PADDING
	graph.building_rect = Rect2(
		Vector2(2.0 * CS + pad.x, 2.0 * CS + pad.y),
		Vector2(4.0 * CS - 2.0 * pad.x, 4.0 * CS - 2.0 * pad.y)
	)

	return graph

# ─────────────────────────────────────────────────────────────
#  Horizontal street builder
# ─────────────────────────────────────────────────────────────

func _add_h_street(
	graph: BoardGraph, street_id: StringName, prefix: String,
	even_y: float, odd_y: float, display_start: int
) -> int:
	var idx := display_start
	for i in H_CELLS:
		var nid := StringName("%s_e_%d" % [prefix, i])
		var node := BoardNode.new()
		node.id = nid
		node.position = Vector2(float(i) * CS, even_y)
		node.street_id = street_id
		node.side = 0
		node.display_index = idx
		node.shop_id = SHOP_MAP.get(nid, &"")
		if i < H_CELLS - 1:
			node.next_nodes = [StringName("%s_e_%d" % [prefix, i + 1])]
		graph.nodes[nid] = node
		idx += 1

	for i in H_CELLS:
		var nid := StringName("%s_o_%d" % [prefix, i])
		var col := H_CELLS - 1 - i
		var node := BoardNode.new()
		node.id = nid
		node.position = Vector2(float(col) * CS, odd_y)
		node.street_id = street_id
		node.side = 1
		node.display_index = idx
		node.shop_id = SHOP_MAP.get(nid, &"")
		if i < H_CELLS - 1:
			node.next_nodes = [StringName("%s_o_%d" % [prefix, i + 1])]
		graph.nodes[nid] = node
		idx += 1

	return idx

# ─────────────────────────────────────────────────────────────
#  Vertical street builder
# ─────────────────────────────────────────────────────────────

func _add_v_street(
	graph: BoardGraph, street_id: StringName, prefix: String,
	even_x: float, odd_x: float, display_start: int
) -> int:
	var idx := display_start
	for i in V_CELLS:
		var nid := StringName("%s_e_%d" % [prefix, i])
		var row := V_START_ROW + i
		var node := BoardNode.new()
		node.id = nid
		node.position = Vector2(even_x, float(row) * CS)
		node.street_id = street_id
		node.side = 0
		node.display_index = idx
		node.shop_id = SHOP_MAP.get(nid, &"")
		if i < V_CELLS - 1:
			node.next_nodes = [StringName("%s_e_%d" % [prefix, i + 1])]
		graph.nodes[nid] = node
		idx += 1

	for i in V_CELLS:
		var nid := StringName("%s_o_%d" % [prefix, i])
		var row := V_END_ROW - i
		var node := BoardNode.new()
		node.id = nid
		node.position = Vector2(odd_x, float(row) * CS)
		node.street_id = street_id
		node.side = 1
		node.display_index = idx
		node.shop_id = SHOP_MAP.get(nid, &"")
		if i < V_CELLS - 1:
			node.next_nodes = [StringName("%s_o_%d" % [prefix, i + 1])]
		graph.nodes[nid] = node
		idx += 1

	return idx

# ─────────────────────────────────────────────────────────────
#  Street resources
# ─────────────────────────────────────────────────────────────

func _build_streets(graph: BoardGraph) -> void:
	_register_street(graph, RIVOLI, "Rue de Rivoli",
		"riv", H_CELLS, [CASTIGLIONE, MARCHE])
	_register_street(graph, SAINT_HONORE, "Rue Saint-Honoré",
		"sth", H_CELLS, [CASTIGLIONE, MARCHE])
	_register_street(graph, CASTIGLIONE, "Rue de Castiglione",
		"cas", V_CELLS, [RIVOLI, SAINT_HONORE])
	_register_street(graph, MARCHE, "Rue du Marché",
		"mar", V_CELLS, [RIVOLI, SAINT_HONORE])

func _register_street(
	graph: BoardGraph, street_id: StringName,
	display: String, prefix: String, count: int,
	intersecting: Array[StringName]
) -> void:
	var st := Street.new()
	st.id = street_id
	st.display_name = display
	st.intersecting_streets = intersecting

	for i in count:
		st.even_side_nodes.append(
			StringName("%s_e_%d" % [prefix, i])
		)
	for i in count:
		st.odd_side_nodes.append(
			StringName("%s_o_%d" % [prefix, i])
		)

	graph.streets[street_id] = st

# ─────────────────────────────────────────────────────────────
#  Intersection wiring at the 4 corners
# ─────────────────────────────────────────────────────────────
#
#  Each corner has 2 street-end exit nodes (one from each street).
#  Each exit becomes an Intersection with 2 choices:
#    - Turn onto the perpendicular street
#    - Cross to the opposite sidewalk
#
#  Corners (exit node → [destinations]):
#
#  Top-Right:  riv_e_7  → [mar_e_0, riv_o_0]
#              mar_o_3  → [riv_o_0, mar_e_0]
#
#  Top-Left:   riv_o_7  → [cas_e_0, riv_e_0]
#              cas_o_3  → [riv_e_0, cas_e_0]
#
#  Bot-Right:  sth_e_7  → [mar_o_0, sth_o_0]
#              mar_e_3  → [sth_o_0, mar_o_0]
#
#  Bot-Left:   sth_o_7  → [cas_o_0, sth_e_0]
#              cas_e_3  → [sth_e_0, cas_o_0]

func _wire_intersections(graph: BoardGraph) -> void:
	# Top-Right
	_make_inter(graph, &"riv_e_7", [
		{&"key": &"right_turn",
		 &"dest": &"mar_e_0",
		 &"label": "\u2B9E Rue du Marché"},
		{&"key": &"opposite_side",
		 &"dest": &"riv_o_0",
		 &"label": "\u21C5 Opposite Side"},
	])
	_make_inter(graph, &"mar_o_3", [
		{&"key": &"left_turn",
		 &"dest": &"riv_o_0",
		 &"label": "\u2B9C Rue de Rivoli"},
		{&"key": &"opposite_side",
		 &"dest": &"mar_e_0",
		 &"label": "\u21C5 Opposite Side"},
	])

	# Top-Left
	_make_inter(graph, &"riv_o_7", [
		{&"key": &"left_turn",
		 &"dest": &"cas_e_0",
		 &"label": "\u2B9C Rue de Castiglione"},
		{&"key": &"opposite_side",
		 &"dest": &"riv_e_0",
		 &"label": "\u21C5 Opposite Side"},
	])
	_make_inter(graph, &"cas_o_3", [
		{&"key": &"right_turn",
		 &"dest": &"riv_e_0",
		 &"label": "\u2B9E Rue de Rivoli"},
		{&"key": &"opposite_side",
		 &"dest": &"cas_e_0",
		 &"label": "\u21C5 Opposite Side"},
	])

	# Bottom-Right
	_make_inter(graph, &"sth_e_7", [
		{&"key": &"left_turn",
		 &"dest": &"mar_o_0",
		 &"label": "\u2B9C Rue du Marché"},
		{&"key": &"opposite_side",
		 &"dest": &"sth_o_0",
		 &"label": "\u21C5 Opposite Side"},
	])
	_make_inter(graph, &"mar_e_3", [
		{&"key": &"right_turn",
		 &"dest": &"sth_o_0",
		 &"label": "\u2B9E Rue Saint-Honoré"},
		{&"key": &"opposite_side",
		 &"dest": &"mar_o_0",
		 &"label": "\u21C5 Opposite Side"},
	])

	# Bottom-Left
	_make_inter(graph, &"sth_o_7", [
		{&"key": &"right_turn",
		 &"dest": &"cas_o_0",
		 &"label": "\u2B9E Rue de Castiglione"},
		{&"key": &"opposite_side",
		 &"dest": &"sth_e_0",
		 &"label": "\u21C5 Opposite Side"},
	])
	_make_inter(graph, &"cas_e_3", [
		{&"key": &"left_turn",
		 &"dest": &"sth_e_0",
		 &"label": "\u2B9C Rue Saint-Honoré"},
		{&"key": &"opposite_side",
		 &"dest": &"cas_o_0",
		 &"label": "\u21C5 Opposite Side"},
	])

## Replace a street-end node with an Intersection carrying the
## given choices.
func _make_inter(
	graph: BoardGraph, node_id: StringName,
	choices: Array[Dictionary]
) -> void:
	var old := graph.get_node_by_id(node_id)
	if old == null:
		push_error("ParisDistrictTopology: node '%s' not found" % node_id)
		return

	var inter := Intersection.new()
	inter.id            = old.id
	inter.position      = old.position
	inter.street_id     = old.street_id
	inter.side          = old.side
	inter.shop_id       = old.shop_id
	inter.display_index = old.display_index
	inter.choice_count  = choices.size()

	for c: Dictionary in choices:
		var dest: StringName = c[&"dest"]
		var label: StringName = StringName(c[&"label"] as String)
		var key: StringName = c[&"key"]

		inter.next_nodes.append(dest)
		inter.choice_labels.append(label)
		inter.choice_destinations.append(dest)
		inter.choice_descriptions.append(
			StreetIntersectionRuleSet.get_description(key)
		)

	graph.nodes[node_id] = inter
