extends Node2D

@onready var start: Button = $UI/Control/start
@onready var exit: Button = $UI/Control/exit

@onready var animation_player = $Transition/AnimationPlayer

const GAME_SCENE_PATH = "res://scene/game.tscn"

func _on_exit_pressed() -> void:
	start.disabled = true
	exit.disabled = true
	animation_player.play("fade_to_black")
	await animation_player.animation_finished
	get_tree().quit()

func _on_start_pressed() -> void:
	start.disabled = true
	exit.disabled = true
	animation_player.play("fade_to_black")
	await animation_player.animation_finished
	var error = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	
	if error != OK:
		print("Ошибка при смене сцены. Код ошибки: ", error)
		start.disabled = false
		exit.disabled = false
