extends Node2D

@onready var start: Button = $UI/Control/start
@onready var exit: Button = $UI/Control/exit

# Ссылка на аниматор. Проверьте, что путь ($TransitionLayer/AnimationPlayer) совпадает с вашим деревом сцены!
@onready var animation_player = $Transition/AnimationPlayer

# Убедитесь, что папка действительно называется scene (с маленькой буквы)
const GAME_SCENE_PATH = "res://scene/game.tscn"

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_start_pressed() -> void:
	# 1. Отключаем кнопки (используем новые имена переменных: start и exit)
	start.disabled = true
	exit.disabled = true
	
	# 2. Запускаем анимацию плавного затухания в черное
	animation_player.play("fade_to_black")
	
	# 3. Ждем (ставим код на паузу), пока анимация полностью проиграется
	await animation_player.animation_finished
	
	# 4. Когда экран стал полностью черным, незаметно меняем сцену
	var error = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	
	if error != OK:
		print("Ошибка при смене сцены. Код ошибки: ", error)
		# Если произошла ошибка, возвращаем кнопкам активность
		start.disabled = false
		exit.disabled = false
