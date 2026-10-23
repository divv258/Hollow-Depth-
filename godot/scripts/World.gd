# World.gd - Main world scene controller
# Wires everything together: generator ? tilemap ? enemies ? player ? HUD
extends Node2D

const TILE_SIZE := 32

# --- Scenes to instantiate ----------------------------------------------------
@export var player_scene: PackedScene
@export var mob_a_scene: PackedScene
@export var mob_b_scene: PackedScene
@export var boss_scene: PackedScene

# --- Node refs ----------------------------------------------------------------
@onready var tilemap: TileMapLayer = $TileMap
@onready var entities: Node2D = $Entities
@onready var camera: Camera2D = $Camera2D
@onready var hud: CanvasLayer = $HUD
@onready var background: Node2D = $Background
@onready var fade_rect: ColorRect = $FadeRect

var generator := WorldGenerator.new()
var player_node: CharacterBody2D = null

# --- Tile source IDs in TileSet -----------------------------------------------
const SRC_SOLID  := 0
const SRC_LEDGE  := 1
const SRC_SPIKE  := 2
const SRC_CRACK  := 3

func _ready() -> void:
	add_child(generator)
	_start_act(GameManager.current_act)

func _start_act(act_idx: int) -> void:
	# Generate map data
	generator.generate(act_idx)

	# Apply to tilemap
	_populate_tilemap()

	# Spawn player
	_spawn_player()

	# Spawn enemies
	_spawn_enemies(act_idx)

	# Spawn boss
	_spawn_boss(act_idx)

	# Setup background colours from biome
	_apply_biome(act_idx)

	# Wire HUD
	_connect_hud()

	# Fade in
	_fade_in()

	GameManager.set_state(GameManager.State.PLAYING)

# --- Tilemap ------------------------------------------------------------------
func _populate_tilemap() -> void:
	tilemap.clear()
	for r in range(generator.map_grid.size()):
		var row: Array = generator.map_grid[r]
		for c in range(row.size()):
			var tile: int = row[c]
			match tile:
				WorldGenerator.TILE_SOLID:
					tilemap.set_cell(Vector2i(c, r), SRC_SOLID, Vector2i(0, 0))
				WorldGenerator.TILE_LEDGE:
					tilemap.set_cell(Vector2i(c, r), SRC_LEDGE, Vector2i(0, 0))
				WorldGenerator.TILE_SPIKE:
					tilemap.set_cell(Vector2i(c, r), SRC_SPIKE, Vector2i(0, 0))
				WorldGenerator.TILE_CRACK:
					tilemap.set_cell(Vector2i(c, r), SRC_CRACK, Vector2i(0, 0))

# --- Spawning -----------------------------------------------------------------
func _spawn_player() -> void:
	# Clear old player
	if player_node:
		player_node.queue_free()

	if not player_scene: return
	player_node = player_scene.instantiate() as CharacterBody2D
	player_node.add_to_group("player")
	player_node.global_position = Vector2(5 * TILE_SIZE, 20 * TILE_SIZE)

	# Restore persistent stats from GameManager
	player_node.geo = GameManager.geo
	player_node.atk = GameManager.atk

	entities.add_child(player_node)
	camera.set_target(player_node)

func _spawn_enemies(act_idx: int) -> void:
	var hp_scale := 1.0 + act_idx * 0.25
	for data in generator.mobs_data:
		var scene: PackedScene = mob_a_scene if data["type"] == "mobA" else mob_b_scene
		if not scene: continue
		var mob := scene.instantiate() as CharacterBody2D
		mob.global_position = Vector2(data["col"] * TILE_SIZE, data["row"] * TILE_SIZE)
		mob.max_hp *= hp_scale
		mob.connect("enemy_died", _on_enemy_died)
		entities.add_child(mob)

func _spawn_boss(act_idx: int) -> void:
	if not boss_scene: return
	var boss := boss_scene.instantiate()
	boss.act_index = act_idx
	boss.max_hp = 600.0 + act_idx * 200.0
	boss.boss_name = GameManager.BIOMES[act_idx]["boss_name"]
	boss.global_position = generator.boss_spawn
	boss.connect("boss_hp_changed", hud.on_boss_hp_changed)
	boss.connect("boss_state_changed", hud.on_boss_state_changed)
	boss.connect("boss_defeated", _on_boss_defeated)
	entities.add_child(boss)
	hud.show_boss_bar(boss.boss_name, act_idx)

# --- Biome Visuals ------------------------------------------------------------
func _apply_biome(act_idx: int) -> void:
	var biome := GameManager.BIOMES[act_idx]
	# Set background gradient colours
	if background.has_method("set_colors"):
		background.set_colors(biome["bg_top"], biome["bg_bottom"])

# --- HUD Wiring ---------------------------------------------------------------
func _connect_hud() -> void:
	if not player_node: return
	player_node.connect("health_changed", hud.on_health_changed)
	player_node.connect("soul_changed", hud.on_soul_changed)
	player_node.connect("stamina_changed", hud.on_stamina_changed)
	player_node.connect("geo_changed", hud.on_geo_changed)
	player_node.connect("player_died", _on_player_died)
	player_node._update_hud()

# --- Events -------------------------------------------------------------------
func _on_enemy_died(pos: Vector2, geo_reward: int) -> void:
	player_node.collect_geo(geo_reward)
	camera.add_trauma(7.0)
	_spawn_particles(pos, Color("#ff7700"), 26)

func _on_boss_defeated(geo_reward: int) -> void:
	player_node.collect_geo(geo_reward)
	camera.add_trauma(18.0)
	hud.hide_boss_bar()
	_spawn_particles(generator.boss_spawn, Color("#ffd152"), 55)
	# Save and transition
	GameManager.geo = player_node.geo
	GameManager.atk = player_node.atk
	await get_tree().create_timer(2.5).timeout
	_fade_to_next_act()

func _on_player_died() -> void:
	await get_tree().create_timer(1.2).timeout
	# Respawn at last bench
	player_node.respawn_at(player_node.respawn_position)
	GameManager.set_state(GameManager.State.PLAYING)

func _fade_to_next_act() -> void:
	fade_rect.visible = true
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.0)
	await tween.finished
	GameManager.next_act()
	if GameManager.current_act >= GameManager.BIOMES.size():
		get_tree().change_scene_to_file("res://scenes/ui/EndScreen.tscn")
	else:
		_start_act(GameManager.current_act)
	tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 1.2)

func _fade_in() -> void:
	fade_rect.visible = true
	fade_rect.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 1.2)

func _spawn_particles(pos: Vector2, color: Color, count: int) -> void:
	# Simple CPU particles
	for i in range(count):
		var rect := ColorRect.new()
		rect.size = Vector2(4, 4)
		rect.color = color
		rect.global_position = pos
		add_child(rect)
		var tween := create_tween()
		var target := pos + Vector2(randf_range(-80, 80), randf_range(-80, 80))
		tween.tween_property(rect, "global_position", target, 0.5)
		tween.parallel().tween_property(rect, "modulate:a", 0.0, 0.5)
		tween.tween_callback(rect.queue_free)
