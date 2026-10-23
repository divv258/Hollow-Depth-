# Projectile.gd - Fired by player (Vengeful Spirit) or boss
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 12.5 * 32 * 0.0625
var friendly: bool = true   # true = hits enemies, false = hits player
var life: int = 55

@onready var sprite: Node2D = $Sprite

func _ready() -> void:
	if sprite:
		sprite.modulate = Color("#5ce1e6") if friendly else Color("#e03c58")

func _physics_process(_delta: float) -> void:
	position += direction * speed
	life -= 1
	if life <= 0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if friendly and body.has_method("take_damage"):
		body.take_damage(85, int(sign(direction.x)))
		queue_free()
	elif not friendly and body.is_in_group("player"):
		body.take_damage(1)
		queue_free()
