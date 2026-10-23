# Camera.gd - Smooth follow camera with screen shake
# Ported from JS camera object and addTrauma() / camera shake system
extends Camera2D

var shake_trauma: float = 0.0
var shake_strength: float = 55.0  # matches HTML default (55%)
var target: Node2D = null

const MAX_SHAKE_OFFSET := 12.0
const TRAUMA_DECAY := 0.86

func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0

func _process(_delta: float) -> void:
	if target:
		global_position = target.global_position

	# Screen shake
	if shake_trauma > 0:
		shake_trauma *= TRAUMA_DECAY
		if shake_trauma < 0.01:
			shake_trauma = 0.0
		var shake := shake_trauma * shake_trauma  # squared for feel
		offset = Vector2(
			randf_range(-MAX_SHAKE_OFFSET, MAX_SHAKE_OFFSET) * shake * (shake_strength / 55.0),
			randf_range(-MAX_SHAKE_OFFSET, MAX_SHAKE_OFFSET) * shake * (shake_strength / 55.0)
		)
	else:
		offset = Vector2.ZERO

func add_trauma(amount: float) -> void:
	shake_trauma = min(1.0, shake_trauma + amount / 100.0)

func set_target(node: Node2D) -> void:
	target = node
