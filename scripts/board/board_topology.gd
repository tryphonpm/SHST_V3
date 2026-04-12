## Abstract factory that produces a BoardGraph describing a board layout.
## Concrete subclasses (e.g. RectangularLoopTopology) override build_graph()
## to generate their specific geometry. All runtime queries go through the
## BoardGraph itself — this class is only used at session-start.
##
## TODO: will support Paris-district topology and graph-based routing.
class_name BoardTopology
extends RefCounted

## Build and return a fully connected BoardGraph for one game session.
## Override in subclasses.
func build_graph() -> BoardGraph:
	push_error("BoardTopology.build_graph() is abstract — override in subclass")
	return null
