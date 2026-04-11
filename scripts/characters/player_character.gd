class_name PlayerCharacter
extends CharacterBody2D

signal movement_complete

enum State { IDLE, WALKING, CELEBRATING }

@export var player_data: PlayerData

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var _state: State = State.IDLE
var _move_queue: Array[Vector2] = []

func _ready() -> void:
	_enter_state(State.IDLE)

func _physics_process(delta: float) -> void:
	match _state:
		State.IDLE:
			pass
		State.WALKING:
			_process_walk(delta)
		State.CELEBRATING:
			pass

# ---- State machine ----

func _enter_state(new_state: State) -> void:
	_state = new_state
	match _state:
		State.IDLE:
			sprite.play("idle")
		State.WALKING:
			sprite.play("walk")
		State.CELEBRATING:
			sprite.play("celebrate")

# ---- Movement ----

## Enqueue a list of world positions to walk through in order.
func walk_along(path_positions: Array[Vector2]) -> void:
	_move_queue = path_positions.duplicate()
	_enter_state(State.WALKING)

func _process_walk(_delta: float) -> void:
	if _move_queue.is_empty():
		_enter_state(State.IDLE)
		movement_complete.emit()
		return

	var target := _move_queue[0]
	var direction := (target - global_position).normalized()
	velocity = direction * GameConfig.PLAYER_MOVE_SPEED

	_update_facing(direction)
	move_and_slide()

	if global_position.distance_to(target) < 4.0:
		global_position = target
		_move_queue.remove_at(0)

func _update_facing(direction: Vector2) -> void:
	if direction.x < -0.1:
		sprite.flip_h = true
	elif direction.x > 0.1:
		sprite.flip_h = false

func celebrate() -> void:
	_enter_state(State.CELEBRATING)
