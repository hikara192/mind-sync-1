extends Node2D

@onready var startgame = $start
@onready var exitgame = $exit

# Убедитесь, что папка действительно называется scene (с маленькой буквы)
const GAME_SCENE_PATH = "res://scene/game.tscn"

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_start_pressed() -> void:
	# ИСПРАВЛЕНО: заменено change_scene на change_scene_to_file
	var error = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	
	if error != OK:
		print("Ошибка при смене сцены. Код ошибки: ", error)
