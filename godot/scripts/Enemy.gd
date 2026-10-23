# Enemy.gd - Base enemy (MobA and MobB)
# Ported from JS mobA/mobB logic
extends CharacterBody2D

# --- Signals ------------------------------------------------------------------
signal enemy_died(position: Vector2, geo_reward: int)

# --- Config -------------------------------------------------------------------
@export var mob_type: String = "mobA"  # "mobA" or "mobB"
@export var max_hp: float = 50.0
@export var move_speed: float = 1.3
@export var geo_reward: int = 25
@export var is_flying: bool = false    # mobB floats, mobA walks

# --- State Machine ------------------------------------------------------------
enum State { PATROL, CHASE, ATTACK, HURT, DEAD }
var state: State = State.PATROL
var state_timer: int = 0

# --- Runtime ------------------------------------------------------------------
var hp: float
var facing: int = 1
var flash_timer: int = 0
var kb_velocity: float = 0.0       # knockback X
var base_y: float = 0.0            # for mobB float oscillation
var anim_tick: int = 0
var patrol_dir: int = 1
var detect_range: float = 200.0
var attack_range: float = 40.0

const GRAVITY := 0.5 * 32 * 0.0625
const TILE_SIZE := 32

@onready var sprite: Node2D = $Sprite
@onready var hitbox: Area2D = $Hitbox
@onready var detect_area: Area2D = $DetectArea

func _ready() -> void:
	hp = max_hp
	base_y = global_position.y
	facing = patrol_dir

func _physics_process(_delta: float) -> void:
	if GameManager.current_state != GameManager.State.PLAYING:
		return
	if state == State.DEAD:
		return

	anim_tick += 1
	_tick_timers()
	_state_machine()

	if not is_flying:
		velocity.y += GRAVITY
		velocity.y = min(velocity.y, 18.0)

	move_and_slide()

	if sprite:
		sprite.scale.x = float(facing)
		if flash_timer > 0:
			sprite.modulate = Color(1.8, 0.4, 0.4)
		else:
			sprite.modulate = Color.WHITE

# --- State Machine ------------------------------------------------------------
func _state_machine() -> void:
	var player := _find_player()
	match state:
		State.PATROL:
			_do_patrol(player)
		State.CHASE:
			_do_chase(player)
		State.ATTACK:
			_do_attack(player)
		State.HURT:
			state_timer -= 1
			velocity.x = kb_velocity
			kb_velocity = move_toward(kb_velocity, 0, 1.5)
			if state_timer <= 0:
				state = State.PATROL

func _do_patrol(player) -> void:
	velocity.x = patrol_dir * move_speed * 32

	if is_flying:
		velocity.y = sin(anim_tick * 0.05) * 0.8

	# Check for wall / ledge - reverse direction
	if is_on_wall():
		patrol_dir *= -1
	elif not is_flying and not _has_floor_ahead():
		patrol_dir *= -1

	facing = patrol_dir

	# Detect player
	if player and _dist_to(player) < detect_range:
		state = State.CHASE

func _do_chase(player) -> void:
	if not player:
		state = State.PATROL
		return

	var diff := player.global_position.x - global_position.x
	facing = int(sign(diff))
	velocity.x = facing * move_speed * 32 * 1.5

	if is_flying:
		var dy := player.global_position.y - global_position.y
		velocity.y = sign(dy) * move_speed * 20

	# Lost player
	if _dist_to(player) > detect_range * 1.5:
		state = State.PATROL
		return

	# In attack range
	if _dist_to(player) < attack_range:
		state = State.ATTACK
		state_timer = 30

func _do_attack(player) -> void:
	velocity.x = 0
	state_timer -= 1
	if state_timer <= 0:
		if player and _dist_to(player) < attack_range * 1.2:
			_melee_hit(player)
		state = State.CHASE

func _melee_hit(player) -> void:
	if player.has_method("take_damage"):
		player.take_damage(1)

# --- Damage Handling ----------------------------------------------------------
func take_damage(amount: float, hit_dir: int = 1) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	flash_timer = 7
	kb_velocity = hit_dir * 7.0 * 32
	state = State.HURT
	state_timer = 12

	if hp <= 0:
		_die()

func _die() -> void:
	state = State.DEAD
	emit_signal("enemy_died", global_position, geo_reward)
	# Spawn particles via get_parent()
	queue_free()

# --- Helpers ------------------------------------------------------------------
func _find_player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _dist_to(node: Node) -> float:
	return global_position.distance_to(node.global_position)

func _has_floor_ahead() -> bool:
	# Raycast slightly ahead and below to detect ledge
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(facing * (get_meta("width", 32) / 2 + 4), 0),
		global_position + Vector2(facing * (get_meta("width", 32) / 2 + 4), TILE_SIZE * 1.2),
		collision_mask
	)
	var result := space.intersect_ray(query)
	return not result.is_empty()

func _tick_timers() -> void:
	if flash_timer > 0: flash_timer -= 1
