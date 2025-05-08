extends Control

@onready var logo_animation_player: AnimationPlayer = $Logo/LogoAnimationPlayer
@onready var button_animation_player: AnimationPlayer = $MainContent/ContentVBox/ButtonAnimationPlayer

func _ready() -> void:
	logo_animation_player.play("logo_fade_in")
	button_animation_player.play("button_fade_in")

	await logo_animation_player.animation_finished

	logo_animation_player.play("breathing")
