# WorldGenerator.gd - Procedural map generation
# Ported directly from JS buildLevelMap() and buildTutorialMap()
extends Node

const TILE_SIZE := 32
const MAP_W := 420
const MAP_H := 44

# Tile types (matching HTML source)
const TILE_EMPTY  := 0
const TILE_SOLID  := 1
const TILE_LEDGE  := 2  # one-way platform
const TILE_SPIKE  := 3  # damage
const TILE_CRACK  := 5  # breakable secret floor

var map_grid: Array = []  # [row][col] of tile IDs
var actual_map_w: int = MAP_W
var benches: Array = []
var chests: Array = []
var mobs_data: Array = []
var gate_pos: Vector2 = Vector2.ZERO
var boss_spawn: Vector2 = Vector2.ZERO

# --- Main Entry ---------------------------------------------------------------
func generate(act_idx: int) -> void:
	_reset()
	var hp_scale := 1.0 + act_idx * 0.25

	var c := 2
	var f := 23

	match act_idx:
		0: c = _build_act1(c, f, hp_scale)
		1: c = _build_act2(c, f, hp_scale)
		2: c = _build_act3(c, f, hp_scale)

	# Boss arena at end
	_carve(c, f - 10, c + 28, f - 1)
	boss_spawn = Vector2((c + 14) * TILE_SIZE, (f - 6) * TILE_SIZE)
	gate_pos = Vector2((c + 24) * TILE_SIZE, (f - 1) * TILE_SIZE)
	actual_map_w = c + 30

	# Trim grid
	for row in map_grid:
		while row.size() > actual_map_w:
			row.pop_back()

func generate_tutorial() -> void:
	_reset()
	# Tutorial is a simple linear level - implemented same as JS
	var c := 2
	var f := 23
	c = _flat(c, f, 12, 0, {})
	c = _flat(c, f - 2, 8, 0, {})
	f -= 2
	c = _flat(c, f, 10, 0, {"sp": [4, 6]})
	c = _flat(c, f, 11, 0, {"bench": [8, "Training Bench"]})
	c = _flat(c, f, 12, 0, {"a": 1})
	c = _flat(c, f, 10, 0, {"sec": 5})
	c = _flat(c, f, 8, 0, {})
	f += 4
	c = _flat(c, f, 9, 0, {"sp": [3, 5]})
	f -= 4
	c = _flat(c, f, 8, 0, {"b": 1})
	gate_pos = Vector2((c + 10) * TILE_SIZE, f * TILE_SIZE - 96)
	c = _flat(c, f, 16, 0, {})
	actual_map_w = c + 6

# --- Act Builders -------------------------------------------------------------
func _build_act1(c: int, f: int, hp_scale: float) -> int:
	c = _flat(c, f, 14, 0, {"bench": [3, "Weaver's Glade Bench"], "b": 1})
	f -= 2; c = _flat(c, f, 8, 0, {"a": 1})
	c = _flat(c, f, 10, 0, {"sp": [1, 3], "b": 1, "sec": 6})
	f += 3; c = _flat(c, f, 7, 0, {"a": 1})
	f += 4; c = _flat(c, f, 9, 0, {"sp": [3, 5], "a": 1})
	f -= 4; c = _flat(c, f, 8, 0, {"b": 1})
	c = _drop(c, f, 6); f += 6
	c = _flat(c, f, 12, 0, {"sp": [4, 6], "a": 2, "b": 1, "bench": [10, "Sunken Roots Bench"]})
	f -= 3; c = _flat(c, f, 8, 0, {"b": 1})
	c = _climb(c, f, 3); f -= 9
	c = _flat(c, f, 10, 0, {"a": 1, "b": 2, "chest": 8})
	f += 3; c = _flat(c, f, 8, 0, {"a": 1})
	f += 3; c = _flat(c, f, 7, 0, {"b": 1, "sp": [2, 3]})
	c = _flat(c, f, 10, 0, {"a": 2})
	f -= 3; c = _flat(c, f, 8, 0, {"b": 1})
	c = _climb(c, f, 3); f -= 9
	c = _flat(c, f, 12, 0, {"b": 2, "a": 1, "chest": 6, "bench": [2, "High Canopy Bench"]})
	f += 3; c = _flat(c, f, 8, 0, {"b": 1})
	f += 3; c = _flat(c, f, 8, 0, {"a": 1, "sp": [2, 3]})
	c = _drop(c, f, 8); f += 8
	c = _flat(c, f, 14, 0, {"a": 2, "b": 1, "sp": [5, 7]})
	return c

func _build_act2(c: int, f: int, hp_scale: float) -> int:
	c = _flat(c, f, 10, 0, {"bench": [3, "Crystal Foyer Bench"]})
	c = _climb(c, f, 5); f -= 15
	c = _flat(c, f, 12, 0, {"sp": [1, 3], "b": 2, "sec": 7})
	f += 3; c = _flat(c, f, 8, 0, {"a": 1, "b": 2, "bench": [4, "Queen's Canopy Bench"]})
	f += 3; c = _flat(c, f, 8, 0, {"b": 2, "chest": 6})
	f += 3; c = _flat(c, f, 6, 0, {"b": 1})
	f += 3; c = _flat(c, f, 8, 0, {"a": 1, "b": 1})
	c = _flat(c, f, 10, 0, {"a": 2})
	f += 3; c = _flat(c, f, 8, 0, {"sp": [2, 4], "b": 1})
	c = _drop(c, f, 10); f += 10
	c = _flat(c, f, 12, 0, {"sp": [4, 6], "a": 2, "b": 1, "bench": [9, "Sunken Hothouse Bench"]})
	f -= 3; c = _flat(c, f, 8, 0, {"b": 1})
	f -= 3; c = _flat(c, f, 8, 0, {"a": 1})
	c = _climb(c, f, 3); f -= 9
	c = _flat(c, f, 10, 0, {"sp": [3, 5], "b": 2, "chest": 8})
	f += 4; c = _flat(c, f, 9, 0, {"sp": [2, 4], "a": 1})
	f -= 4; c = _flat(c, f, 8, 0, {"b": 1})
	f += 3; c = _flat(c, f, 8, 0, {"a": 2})
	c = _flat(c, f, 10, 0, {"a": 1, "b": 2, "sp": [3, 5]})
	f += 3; c = _flat(c, f, 8, 0, {"a": 1})
	c = _flat(c, f, 10, 0, {"b": 2, "sp": [3, 5], "chest": 8})
	return c

func _build_act3(c: int, f: int, hp_scale: float) -> int:
	c = _flat(c, f, 8, 0, {"bench": [3, "Foundry Gate Bench"]})
	c = _drop(c, f, 8); f += 8
	c = _flat(c, f, 10, 0, {"sp": [3, 5], "a": 1, "b": 1})
	f += 3; c = _flat(c, f, 8, 0, {"a": 1, "b": 1})
	c = _flat(c, f, 10, 0, {"sp": [3, 5], "a": 2, "chest": 9, "bench": [7, "Molten Stairs Bench"]})
	c = _climb(c, f, 3); f -= 9
	c = _flat(c, f, 10, 0, {"sp": [2, 4], "a": 1, "b": 2, "sec": 7})
	f -= 3; c = _flat(c, f, 8, 0, {"a": 2})
	c = _climb(c, f, 3); f -= 9
	c = _flat(c, f, 10, 0, {"b": 3, "chest": 5, "bench": [2, "Bell Hall Bench"]})
	c = _drop(c, f, 10); f += 10
	c = _flat(c, f, 10, 0, {"sp": [3, 5], "a": 2})
	f += 3; c = _flat(c, f, 8, 0, {"a": 1, "b": 1})
	f += 4; c = _flat(c, f, 9, 0, {"sp": [3, 5], "a": 1})
	f -= 4; c = _flat(c, f, 8, 0, {"b": 1})
	c = _flat(c, f, 10, 0, {"sp": [2, 4], "a": 2, "b": 1})
	f -= 3; c = _flat(c, f, 8, 0, {"a": 1})
	c = _climb(c, f, 5); f -= 15
	return c

# --- Primitive Builders -------------------------------------------------------
func _flat(c: int, f: int, length: int, _df: int, opts: Dictionary) -> int:
	var height := opts.get("h", 7)
	_carve(c, f - height, c + length - 1, f - 1)

	if opts.has("sp"):
		var sp: Array = opts["sp"]
		_spikes(c + sp[0], c + sp[1], f)

	for i in range(opts.get("a", 0)):
		var col := c + int(length * (i + 1) / (opts.get("a", 0) + 1))
		mobs_data.append({"type": "mobA", "col": col, "row": f - 3})

	for i in range(opts.get("b", 0)):
		var col := c + int(length * (i + 1) / (opts.get("b", 0) + 1))
		mobs_data.append({"type": "mobB", "col": col, "row": f - 4})

	if opts.has("chest"):
		chests.append({"col": c + opts["chest"], "row": f, "opened": false})

	if opts.has("bench"):
		var b: Array = opts["bench"]
		benches.append({"col": c + b[0], "row": f, "name": b[1]})

	if opts.has("sec"):
		var m := c + opts["sec"]
		_carve(m - 2, f + 1, m + 2, f + 3)
		for k in range(-1, 2):
			_set_tile(m + k, f, TILE_CRACK)
		chests.append({"col": m, "row": f + 4, "opened": false})

	return c + length

func _drop(c: int, f: int, depth: int) -> int:
	_carve(c, f - 7, c + 5, f + depth - 1)
	return c + 6

func _climb(c: int, f: int, n: int) -> int:
	_carve(c, f - 3 * n - 7, c + 9, f - 1)
	for i in range(1, n + 1):
		if i % 2 == 1:
			_ledges(c + 5, c + 9, f - 3 * i)
		else:
			_ledges(c, c + 4, f - 3 * i)
	return c + 10

# --- Grid Primitives ----------------------------------------------------------
func _reset() -> void:
	map_grid = []
	benches.clear()
	chests.clear()
	mobs_data.clear()
	for _r in range(MAP_H):
		map_grid.append(Array())
		map_grid[-1].resize(MAP_W)
		map_grid[-1].fill(TILE_SOLID)

func _carve(c1: int, r1: int, c2: int, r2: int) -> void:
	for r in range(max(1, r1), min(MAP_H - 1, r2) + 1):
		for c in range(max(1, c1), min(MAP_W - 1, c2) + 1):
			map_grid[r][c] = TILE_EMPTY

func _set_tile(c: int, r: int, val: int) -> void:
	if r >= 0 and r < MAP_H and c >= 0 and c < MAP_W:
		map_grid[r][c] = val

func _spikes(c1: int, c2: int, r: int) -> void:
	for c in range(c1, c2 + 1):
		_set_tile(c, r, TILE_SPIKE)

func _ledges(c1: int, c2: int, r: int) -> void:
	for c in range(c1, c2 + 1):
		_set_tile(c, r, TILE_LEDGE)
