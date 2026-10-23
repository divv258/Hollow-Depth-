# Player.gd - CharacterBody2D
# Faithfully ported from the HTML5 canvas game
extends CharacterBody2D

# --- Signals ------------------------------------------------------------------
signal health_changed(current: int, maximum: int)
signal soul_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal geo_changed(amount: int)
signal player_died
signal player_damaged(amount: int)

# --- Constants (ported from JS, scaled to Godot units px=1) ------------------
const TILE_SIZE       := 32
const SPEED           := 5.2  * TILE_SIZE * 0.0625   # ˜ 166 px/s at 60fps
const JUMP_FORCE      := -13.2 * TILE_SIZE * 0.0625
const GRAVITY         := 0.50  * TILE_SIZE * 0.0625
const WALL_SLIDE_GRAV := 0.18  * TILE_SIZE * 0.0625
const DASH_SPEED      := 14.0  * TILE_SIZE * 0.0625
const DASH_DURATION   := 10    # frames
const DASH_COOLDOWN   := 35    # frames
const COYOTE_TIME     := 6     # frames
const INVULN_FRAMES   := 50
const FOCUS_TIME      := 58    # frames held to heal
const POGO_BOUNCE     := -11.6 * TILE_SIZE * 0.0625

# --- Stats --------------------------------------------------------------------
@export var masks: int = 9
@export var max_masks: int = 9
@export var soul: int = 66
@export var max_soul: int = 99
@export var stamina: float = 100.0
@export var max_stamina: float = 100.0
@export var geo: int = 0
@export var atk: int = 42

# --- State Flags --------------------------------------------------------------
var facing: int = 1         # 1=right, -1=left
var grounded: bool = false
var coyote_timer: int = 0
var wall_sliding: bool = false
var wall_dir: int = 0
var is_sitting: bool = false
var invuln: int = 0
var hurt_timer: int = 0

# --- Action Timers ------------------------------------------------------------
var slash_timer: int = 0
var slash_combo: int = 1      # alternates +1/-1
var slash_dir: String = "RIGHT"
var dash_timer: int = 0
var dash_cd: int = 0
var focus_timer: int = 0

# --- Visual -------------------------------------------------------------------
var stretch_x: float = 1.0
var stretch_y: float = 1.0
var anim_tick: int = 0
var light_flash: int = 0
var respawn_position: Vector2

# --- References ---------------------------------------------------------------
@onready var slash_hitbox: Area2D = $SlashHitbox
@onready var sprite: Node2D = $Sprite
@onready var coyote_timer_node: Timer = $CoyoteTimer

func _ready() -> void:
	respawn_position = global_position
	_update_hud()

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.State.PLAYING:
		return

	anim_tick += 1
	_tick_timers()
	_handle_stamina_regen(delta)
	_handle_input()
	_apply_gravity()
	_apply_stretch_lerp()
	move_and_slide()
	_check_grounded()
	_handle_wall_slide()
	_check_hazards()

# --- Input --------------------------------------------------------------------
func _handle_input() -> void:
	if is_sitting:
		if Input.is_action_just_pressed("ui_cancel"):
			is_sitting = false
		return

	var dir := Input.get_axis("move_left", "move_right")

	# Dash (overrides movement)
	if dash_timer > 0:
		velocity.x = facing * DASH_SPEED
		velocity.y = 0.0
		return

	# Horizontal movement
	if dir != 0:
		velocity.x = dir * SPEED
		facing = int(sign(dir))
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Jump
	if Input.is_action_just_pressed("jump"):
		if grounded or coyote_timer > 0:
			_do_jump()
		elif wall_sliding:
			_do_wall_jump()

	# Variable jump height
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.55

	# Dash
	if Input.is_action_just_pressed("dash") and dash_cd <= 0 and stamina >= 30:
		_do_dash()

	# Attack
	if Input.is_action_just_pressed("attack"):
		_handle_slash()

	# Focus/Heal (hold)
	if Input.is_action_pressed("heal") and grounded and not is_sitting:
		focus_timer += 1
		if focus_timer >= FOCUS_TIME and soul >= 33:
			_do_focus()
			focus_timer = 0
	else:
		focus_timer = 0

	# Vengeful Spirit (soul spell)
	if Input.is_action_just_pressed("spell") and soul >= 33:
		_cast_vengeful_spirit()

func _do_jump() -> void:
	velocity.y = JUMP_FORCE
	coyote_timer = 0
	stretch_x = 0.72
	stretch_y = 1.32

func _do_wall_jump() -> void:
	velocity.y = JUMP_FORCE
	velocity.x = -wall_dir * SPEED * 1.1
	wall_sliding = false
	stretch_x = 0.72
	stretch_y = 1.32

func _do_dash() -> void:
	if dash_cd > 0 or stamina < 30:
		return
	dash_timer = DASH_DURATION
	dash_cd = DASH_COOLDOWN
	stamina -= 30.0
	invuln = DASH_DURATION + 2
	stretch_x = 1.32
	stretch_y = 0.68
	# Spawn afterimage effect via signal/event
	emit_signal("stamina_changed", stamina, max_stamina)

func _do_focus() -> void:
	soul -= 33
	masks = min(max_masks, masks + 2)
	stretch_x = 1.1
	stretch_y = 0.92
	emit_signal("health_changed", masks, max_masks)
	emit_signal("soul_changed", soul, max_soul)

func _cast_vengeful_spirit() -> void:
	if soul < 33:
		return
	soul -= 33
	light_flash = 22
	# Spawn projectile
	var proj_scene := load("res://scenes/Projectile.tscn") as PackedScene
	if proj_scene:
		var proj := proj_scene.instantiate()
		proj.global_position = global_position + Vector2(facing * 26, 16)
		proj.direction = Vector2(facing, 0)
		proj.friendly = true
		get_parent().add_child(proj)
	emit_signal("soul_changed", soul, max_soul)

# --- Slash / Combat -----------------------------------------------------------
func _handle_slash() -> void:
	if slash_timer > 0 or is_sitting:
		return

	slash_timer = 11
	slash_combo *= -1
	stretch_x = 1.18
	stretch_y = 0.88

	# Determine direction
	if Input.is_action_pressed("look_up"):
		slash_dir = "UP"
	elif Input.is_action_pressed("look_down") and not grounded:
		slash_dir = "DOWN"
	else:
		slash_dir = "RIGHT" if facing == 1 else "LEFT"

	# Compute reach point
	var reach := _get_slash_reach()

	# Hit enemies in range
	var space := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = reach
	query.collision_mask = 0b0010  # enemy layer
	var hits := space.intersect_point(query, 8)
	for hit in hits:
		var body = hit.collider
		if body.has_method("take_damage"):
			var is_pogo := (slash_dir == "DOWN")
			body.take_damage(atk, facing)
			soul = min(max_soul, soul + 22)
			if is_pogo:
				velocity.y = POGO_BOUNCE
				dash_cd = 0
			emit_signal("soul_changed", soul, max_soul)

func _get_slash_reach() -> Vector2:
	var cx := global_position.x + 12
	var cy := global_position.y + 18
	match slash_dir:
		"RIGHT": return Vector2(cx + 44, cy)
		"LEFT":  return Vector2(cx - 24, cy)
		"UP":    return Vector2(cx, cy - 22)
		"DOWN":  return Vector2(cx, cy + 52)
	return Vector2(cx, cy)

# --- Damage -------------------------------------------------------------------
func take_damage(amount: int = 1) -> void:
	if invuln > 0 or dash_timer > 0:
		return
	hurt_timer = 18
	is_sitting = false
	masks = max(0, masks - amount)
	invuln = INVULN_FRAMES
	stretch_x = 0.8
	stretch_y = 1.2
	emit_signal("player_damaged", amount)
	emit_signal("health_changed", masks, max_masks)
	if masks <= 0:
		_die()

func _die() -> void:
	emit_signal("player_died")
	GameManager.set_state(GameManager.State.DEAD)

func respawn_at(pos: Vector2) -> void:
	global_position = pos
	respawn_position = pos
	masks = max_masks
	velocity = Vector2.ZERO
	invuln = 60
	emit_signal("health_changed", masks, max_masks)

# --- Physics Helpers ----------------------------------------------------------
func _apply_gravity() -> void:
	if not grounded:
		if wall_sliding:
			velocity.y += WALL_SLIDE_GRAV
			velocity.y = min(velocity.y, 2.0)
		else:
			velocity.y += GRAVITY
			velocity.y = min(velocity.y, 18.0)

func _check_grounded() -> void:
	var was_grounded := grounded
	grounded = is_on_floor()
	if grounded and not was_grounded:
		# Land squash
		if velocity.y > 6.0:
			stretch_x = 1.24
			stretch_y = 0.78
		coyote_timer = COYOTE_TIME
	elif not grounded and was_grounded:
		coyote_timer = COYOTE_TIME

func _handle_wall_slide() -> void:
	wall_sliding = false
	if not grounded and is_on_wall() and velocity.y > 0:
		wall_sliding = true
		wall_dir = -1 if get_wall_normal().x > 0 else 1

func _check_hazards() -> void:
	# Spike damage handled by Area2D in world scene
	pass

# --- Timers -------------------------------------------------------------------
func _tick_timers() -> void:
	if slash_timer > 0:   slash_timer -= 1
	if dash_timer > 0:    dash_timer -= 1
	if dash_cd > 0:       dash_cd -= 1
	if invuln > 0:        invuln -= 1
	if hurt_timer > 0:    hurt_timer -= 1
	if coyote_timer > 0:  coyote_timer -= 1
	if light_flash > 0:   light_flash -= 1

func _handle_stamina_regen(delta: float) -> void:
	if dash_timer <= 0:
		stamina = min(max_stamina, stamina + 0.65)
	emit_signal("stamina_changed", stamina, max_stamina)

func _apply_stretch_lerp() -> void:
	stretch_x = lerp(stretch_x, 1.0, 0.22)
	stretch_y = lerp(stretch_y, 1.0, 0.22)
	if sprite:
		sprite.scale = Vector2(stretch_x * facing, stretch_y)

# --- Bench / Rest -------------------------------------------------------------
func sit_at_bench(bench_position: Vector2) -> void:
	is_sitting = true
	respawn_position = bench_position
	masks = max_masks
	velocity = Vector2.ZERO
	emit_signal("health_changed", masks, max_masks)

func collect_geo(amount: int) -> void:
	geo += amount
	emit_signal("geo_changed", geo)

func _update_hud() -> void:
	emit_signal("health_changed", masks, max_masks)
	emit_signal("soul_changed", soul, max_soul)
	emit_signal("stamina_changed", stamina, max_stamina)
	emit_signal("geo_changed", geo)
