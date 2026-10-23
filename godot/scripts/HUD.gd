# HUD.gd - In-game heads-up display
# Mirrors the HTML HUD: masks (HP), soul bar, stamina bar, geo counter, boss bar
extends CanvasLayer

@onready var geo_label: Label = $MarginContainer/HBox/Left/GeoLabel
@onready var stamina_fill: ColorRect = $MarginContainer/HBox/Left/StaminaBar/Fill
@onready var stamina_trail: ColorRect = $MarginContainer/HBox/Left/StaminaBar/Trail
@onready var masks_container: HBoxContainer = $MarginContainer/HBox/Left/MasksRow
@onready var soul_bar: Control = $MarginContainer/HBox/Left/SoulVessel
@onready var boss_bar_box: VBoxContainer = $BossBarBox
@onready var boss_title_label: Label = $BossBarBox/BossTitle
@onready var boss_state_label: Label = $BossBarBox/BossState
@onready var boss_fill: ColorRect = $BossBarBox/BossBarBg/BossFill
@onready var boss_trail: ColorRect = $BossBarBox/BossBarBg/BossTrail

var max_masks: int = 9
var trail_target: float = 1.0
var boss_trail_target: float = 1.0

func _ready() -> void:
	boss_bar_box.visible = false

func _process(_delta: float) -> void:
	# Smooth trailing bars
	stamina_trail.size.x = lerp(stamina_trail.size.x, stamina_fill.size.x, 0.06)
	boss_trail.size.x = lerp(boss_trail.size.x, boss_fill.size.x, 0.06)

# --- Player Signals -----------------------------------------------------------
func on_health_changed(current: int, maximum: int) -> void:
	max_masks = maximum
	_redraw_masks(current, maximum)

func on_soul_changed(current: int, maximum: int) -> void:
	# Soul vessel fill (draw via shader or simple bar)
	var pct := float(current) / float(maximum)
	if soul_bar and soul_bar.has_method("set_fill"):
		soul_bar.set_fill(pct)

func on_stamina_changed(current: float, maximum: float) -> void:
	var pct := current / maximum
	var bar_w := stamina_fill.get_parent().size.x
	stamina_fill.size.x = bar_w * pct

func on_geo_changed(amount: int) -> void:
	if geo_label:
		geo_label.text = str(amount)

# --- Masks --------------------------------------------------------------------
func _redraw_masks(current: int, maximum: int) -> void:
	if not masks_container: return
	for child in masks_container.get_children():
		child.queue_free()
	for i in range(maximum):
		var mask := ColorRect.new()
		mask.custom_minimum_size = Vector2(20, 25)
		mask.color = Color("#f5f5fa") if i < current else Color("#272536")
		masks_container.add_child(mask)

# --- Boss Bar -----------------------------------------------------------------
func show_boss_bar(boss_name_text: String, act_idx: int) -> void:
	boss_bar_box.visible = true
	boss_title_label.text = boss_name_text
	boss_state_label.text = "STALKING PREY"
	boss_fill.size.x = boss_fill.get_parent().size.x
	boss_trail.size.x = boss_fill.size.x

func hide_boss_bar() -> void:
	boss_bar_box.visible = false

func on_boss_hp_changed(current: float, maximum: float) -> void:
	var pct := max(0.0, current / maximum)
	var bar_w := boss_fill.get_parent().size.x
	boss_fill.size.x = bar_w * pct

func on_boss_state_changed(state_name: String) -> void:
	if boss_state_label:
		boss_state_label.text = state_name
