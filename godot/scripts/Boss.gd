# Boss.gd - Boss enemy (one per act, multi-phase)
# Ported from JS boss object and bossUpdate() logic
extends CharacterBody2D

# --- Signals ------------------------------------------------------------------
signal boss_hp_changed(current: float, maximum: float)
signal boss_state_changed(state_name: String)
signal boss_defeated(geo_reward: int)

# --- Config (set per act in scene) --------------------------------------------
@export var max_hp: float = 600.0
@export var act_index: int = 0
@export var boss_name: String = "BOSS"
@export var geo_reward: int = 300

# --- Phase Thresholds ---------------------------------------------------------
const PHASE2_THRESHOLD := 0.5   # 50% HP
const PHASE3_THRESHOLD := 0.25  # 25% HP

# --- State Machine ------------------------------------------------------------
enum State { IDLE, STALK, CHARGE, LEAP, SHOOT, STUN, DEAD }
var state: State = State.IDLE
var state_timer: int = 0
var attack_cycle: int = 0
var phase: int = 1

# --- Runtime ------------------------------------------------------------------
var hp: float
var flash_timer: int = 0
var anim_angle: float = 0.0
var anim_tick: int = 0
var defeated_triggered: bool = false
var facing: int = 1

const GRAVITY := 0.5 * 32 * 0.0625
const TILE_SIZE := 32
const STALK_SPEED := 2.8 * 32 * 0.0625
const CHARGE_SPEED := 7.5 * 32 * 0.0625

@onready var sprite: Node2D = $Sprite
@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	hp = max_hp
	state = State.STALK
	state_timer = 60

func _physics_process(_delta: float) -> void:
	if GameManager.current_state != GameManager.State.PLAYING:
		return
	if state == State.DEAD:
		return

	anim_tick += 1
	anim_angle += 0.04
	_check_phase()
	_tick_timers()
	_state_machine()
	velocity.y += GRAVITY
	velocity.y = min(velocity.y, 18.0)
	move_and_slide()
	_update_visuals()

# --- Phase Logic --------------------------------------------------------------
func _check_phase() -> void:
	var pct := hp / max_hp
	if pct <= PHASE3_THRESHOLD and phase < 3:
		phase = 3
		_enter_state(State.STUN)
	elif pct <= PHASE2_THRESHOLD and phase < 2:
		phase = 2
		_enter_state(State.STUN)

# --- State Machine ------------------------------------------------------------
func _state_machine() -> void:
	var player := _find_player()
	match state:
		State.STALK:  _do_stalk(player)
		State.CHARGE: _do_charge(player)
		State.LEAP:   _do_leap(player)
		State.SHOOT:  _do_shoot(player)
		State.STUN:   _do_stun()

func _do_stalk(player) -> void:
	if not player: return
	state_timer -= 1
	var diff := player.global_position.x - global_position.x
	facing = int(sign(diff))
	velocity.x = move_toward(velocity.x, facing * STALK_SPEED, 0.5)

	if state_timer <= 0:
		attack_cycle += 1
		# Cycle through attacks based on phase
		match (attack_cycle % (2 + phase)):
			0: _enter_state(State.CHARGE)
			1: _enter_state(State.LEAP)
			_: _enter_state(State.SHOOT)

func _do_charge(player) -> void:
	if not player: return
	state_timer -= 1
	velocity.x = facing * CHARGE_SPEED
	if state_timer <= 0 or is_on_wall():
		velocity.x = 0
		_enter_state(State.STALK)

func _do_leap(player) -> void:
	if not player: return
	state_timer -= 1
	if state_timer == 50:
		# Launch jump toward player
		var diff := player.global_position - global_position
		velocity.y = -12.0 * 32 * 0.0625
		velocity.x = sign(diff.x) * STALK_SPEED * 1.8
	if state_timer <= 0 and is_on_floor():
		_enter_state(State.STALK)

func _do_shoot(player) -> void:
	if not player: return
	state_timer -= 1
	velocity.x = move_toward(velocity.x, 0, 1.0)
	# Fire projectiles at intervals
	if state_timer % 18 == 0 and state_timer > 0:
		_spawn_projectile(player)
	if state_timer <= 0:
		_enter_state(State.STALK)

func _do_stun() -> void:
	state_timer -= 1
	velocity.x = move_toward(velocity.x, 0, 2.0)
	emit_signal("boss_state_changed", "PHASE " + str(phase) + " BEGINS")
	if state_timer <= 0:
		_enter_state(State.STALK)

func _enter_state(new_state: State) -> void:
	state = new_state
	match new_state:
		State.STALK:
			state_timer = 90 - (phase * 15)
			emit_signal("boss_state_changed", "STALKING PREY")
		State.CHARGE:
			state_timer = 35 - (phase * 5)
			emit_signal("boss_state_changed", "CHARGING")
		State.LEAP:
			state_timer = 70
			emit_signal("boss_state_changed", "LEAPING")
		State.SHOOT:
			state_timer = 54
			emit_signal("boss_state_changed", "LAUNCHING SPORES")
		State.STUN:
			state_timer = 80
			emit_signal("boss_state_changed", "STUNNED")

# --- Damage -------------------------------------------------------------------
func take_damage(amount: float, _hit_dir: int = 1) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	flash_timer = 7
	emit_signal("boss_hp_changed", hp, max_hp)
	if hp <= 0 and not defeated_triggered:
		_defeat()

func _defeat() -> void:
	defeated_triggered = true
	state = State.DEAD
	velocity = Vector2.ZERO
	emit_signal("boss_defeated", geo_reward)

# --- Projectile ---------------------------------------------------------------
func _spawn_projectile(player: Node) -> void:
	var proj_scene := load("res://scenes/Projectile.tscn") as PackedScene
	if not proj_scene: return
	var proj := proj_scene.instantiate()
	var dir := (player.global_position - global_position).normalized()
	proj.global_position = global_position + Vector2(0, -16)
	proj.direction = dir
	proj.friendly = false
	proj.speed = 5.0 * 32 * 0.0625
	get_parent().add_child(proj)

# --- Visuals ------------------------------------------------------------------
func _update_visuals() -> void:
	if sprite:
		sprite.scale.x = float(facing)
		if flash_timer > 0:
			sprite.modulate = Color(2.0, 0.5, 0.5)
		else:
			sprite.modulate = Color.WHITE

func _tick_timers() -> void:
	if flash_timer > 0: flash_timer -= 1

func _find_player() -> Node:
	return get_tree().get_first_node_in_group("player")
