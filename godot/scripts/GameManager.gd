# GameManager.gd - Autoload singleton
# Manages global game state, acts, and persistent data
extends Node

# --- Game State ---------------------------------------------------------------
enum State { MENU, PLAYING, PAUSED, TRANSITION, DEAD, WIN }
var current_state: State = State.MENU

# --- Player Persistent Data (carries between acts) ----------------------------
var geo: int = 0
var atk: int = 42
var current_act: int = 0

# --- Biome Definitions (ported from JS BIOMES array) -------------------------
const BIOMES = [
	{
		"name": "ACT I: FORGOTTEN CAVERN",
		"boss_name": "MOSS MOTHER GUARDIAN",
		"bg_top": Color("#081410"),
		"bg_bottom": Color("#030705"),
		"turf_color": Color("#46a852"),
		"turf_highlight": Color("#6be078"),
		"dirt_color": Color("#17221e"),
		"ledge_color": Color("#5e8c6a"),
		"spore_color": Color("#78ff96"),
		"boss_shell": Color("#3f8c4f"),
		"boss_trim": Color("#85e894"),
	},
	{
		"name": "ACT II: QUEEN'S GLASS SANCTUARY",
		"boss_name": "LACE OF THE CONSERVATORY",
		"bg_top": Color("#091b24"),
		"bg_bottom": Color("#040a0f"),
		"turf_color": Color("#3ca6b8"),
		"turf_highlight": Color("#7de8fa"),
		"dirt_color": Color("#14222e"),
		"ledge_color": Color("#639db0"),
		"spore_color": Color("#bef4ff"),
		"boss_shell": Color("#d8ecf2"),
		"boss_trim": Color("#5ce1e6"),
	},
	{
		"name": "ACT III: THE GREAT BELL VEIN",
		"boss_name": "THE BELLKEEPER",
		"bg_top": Color("#1a0f08"),
		"bg_bottom": Color("#0a0604"),
		"turf_color": Color("#b8603c"),
		"turf_highlight": Color("#fa8c5a"),
		"dirt_color": Color("#2e1c14"),
		"ledge_color": Color("#b06340"),
		"spore_color": Color("#ffcea0"),
		"boss_shell": Color("#c87840"),
		"boss_trim": Color("#ffd090"),
	}
]

# --- Settings -----------------------------------------------------------------
var sound_enabled: bool = true
var music_volume: float = 0.7
var sfx_volume: float = 0.1
var camera_shake_strength: float = 0.55
var darkness_level: float = 1.0

# --- Score / Save -------------------------------------------------------------
var best_scores: Array = [0, 0, 0]

func save_best(act: int, score: int) -> void:
	if score > best_scores[act]:
		best_scores[act] = score

func get_biome() -> Dictionary:
	return BIOMES[current_act]

func next_act() -> void:
	current_act = (current_act + 1) % BIOMES.size()

func set_state(s: State) -> void:
	current_state = s
