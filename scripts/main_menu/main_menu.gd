extends Control

@onready var logo_animation_player: AnimationPlayer = $Logo/LogoAnimationPlayer

func _ready() -> void:
	logo_animation_player.play(fade_in)

	await logo_animation_player.animation_finished

	logo_animation_player.play(breathing)
