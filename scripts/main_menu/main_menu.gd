extends Control

@onready var logo_animation_player: AnimationPlayer = $Logo/LogoAnimationPlayer
@onready var button_animation_player: AnimationPlayer = $MainContent/ContentVBox/ButtonAnimationPlayer
@onready var background: TextureRect = $Background
@onready var logo: TextureRect = $Logo

@onready var main_content: MarginContainer = $MainContent
@onready var content_v_box: VBoxContainer = $MainContent/ContentVBox
@onready var start_button: Button = $MainContent/ContentVBox/StartButton
@onready var load_button: Button = $MainContent/ContentVBox/LoadButton
@onready var settings_button: Button = $MainContent/ContentVBox/SettingsButton
@onready var exit_button: Button = $MainContent/ContentVBox/ExitButton
@onready var achievement_button: Button = $MainContent/ContentVBox/AchievementButton

@onready var version_label: Label = $VersionLabel
@onready var sub_menu_animation_player: AnimationPlayer = $SubMenuContainer/SubMenuAnimationPlayer
@onready var sub_menu_container: Control = $SubMenuContainer

@onready var audio_players: Node = $AudioPlayers
@onready var button_hover_sound: AudioStreamPlayer2D = $AudioPlayers/ButtonHoverSound
@onready var button_click_sound: AudioStreamPlayer2D = $AudioPlayers/ButtonClickSound
@onready var background_music: AudioStreamPlayer2D = $AudioPlayers/BackgroundMusic

@onready var transition_rect: ColorRect = $TransitionRect
@onready var transition_animation_player: AnimationPlayer = $TransitionRect/TransitionAnimationPlayer

const SETTINGS_MENU_SCENE: PackedScene = preload("res://scenes/main_menu/SettingsMenu.tscn")
const LOAD_GAME_MENU_SCENE: PackedScene = preload("res://scenes/main_menu/LoadGameMenu.tscn")
const ACHIEVEMENTS_MENU_SCENE: PackedScene = preload("res://scenes/main_menu/AchievementMenu.tscn")

var _current_submenu_instance: Node = null
var _is_transitioning: bool = false

func _ready() -> void:
	transition_rect.show()
	transition_rect.modulate.a = 1.0
	logo.modulate.a = 0.0
	content_v_box.modulate.a = 0.0 
	transition_animation_player.play("fade_in")
	await transition_animation_player.animation_finished

	logo_animation_player.play("logo_fade_in")
	button_animation_player.play("button_fade_in")

	await logo_animation_player.animation_finished

	logo_animation_player.play("breathing")

	start_button.pressed.connect(_on_start_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	achievement_button.pressed.connect(_on_achievements_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)

	for button in content_v_box.get_children():
		if button is Button:
			button.mouse_entered.connect(_play_hover_sound)

func _unhandled_input(event: InputEvent) -> void:
	# ESC键关闭当前子菜单
	if event.is_action_pressed("ui_cancel") and _current_submenu_instance:
		_close_current_submenu()
		get_tree().root.set_input_as_handled() # 阻止事件进一步传播

func _on_start_button_pressed() -> void:
	_play_click_sound()
	# _start_scene_transition("res://scenes/levels/your_first_level.tscn") # 替换为你的游戏开始场景

func _on_load_button_pressed() -> void:
	_play_click_sound()
	_open_submenu(LOAD_GAME_MENU_SCENE, "load_game_selected") # LoadGameMenu应发出load_game_selected信号

func _on_settings_button_pressed() -> void:
	_play_click_sound()
	_open_submenu(SETTINGS_MENU_SCENE)

func _on_achievements_button_pressed() -> void:
	_play_click_sound()
	_open_submenu(ACHIEVEMENTS_MENU_SCENE)

func _on_exit_button_pressed() -> void:
	_play_click_sound()
	# 可以添加确认对话框

# --- 子菜单管理 ---
func _open_submenu(scene: PackedScene, connect_signal_name: String = "") -> void:
	if _current_submenu_instance or _is_transitioning: # 如果已有子菜单或正在过渡，则不执行
		return

	_current_submenu_instance = scene.instantiate()
	sub_menu_container.add_child(_current_submenu_instance)

	# 所有子菜单都应该有一个 "closed" 信号，用于通知主菜单它们需要被关闭
	if not _current_submenu_instance.has_signal("closed"):
		push_warning("Submenu scene " + scene.resource_path + " is missing a 'closed' signal.")
	else:
		_current_submenu_instance.closed.connect(_close_current_submenu, CONNECT_ONE_SHOT) # 一次性连接

	# 如果需要连接子菜单的特定信号（如加载游戏选择）
	if connect_signal_name and _current_submenu_instance.has_signal(connect_signal_name):
		if connect_signal_name == "load_game_selected": # 特定处理加载游戏
			_current_submenu_instance.load_game_selected.connect(_on_load_game_selected_from_submenu, CONNECT_ONE_SHOT)

	# 播放子菜单打开动画
	if sub_menu_animation_player and sub_menu_animation_player.has_animation("slide_in"): # 或 "fade_in"
		sub_menu_animation_player.play("slide_in")
		await sub_menu_animation_player.animation_finished
	else:
		# 如果没有动画，确保它是可见的
		_current_submenu_instance.show()


	_set_main_buttons_interactive(false)

func _close_current_submenu() -> void:
	if not _current_submenu_instance or _is_transitioning:
		return

	var instance_to_close = _current_submenu_instance
	_current_submenu_instance = null # 清除引用，防止在动画期间重复关闭

	# 播放子菜单关闭动画
	if sub_menu_animation_player and sub_menu_animation_player.has_animation("slide_out"): # 或 "fade_out"
		sub_menu_animation_player.play("slide_out")
		await sub_menu_animation_player.animation_finished
	
	if is_instance_valid(instance_to_close):
		instance_to_close.queue_free()

	_set_main_buttons_interactive(true)

func _set_main_buttons_interactive(interactive: bool) -> void:
	for child in content_v_box.get_children():
		if child is Button:
			child.disabled = not interactive
	
	# 可选：视觉上指示禁用状态
	content_v_box.modulate.a = 1.0 if interactive else 0.5


# --- 场景过渡 ---
func _start_scene_transition(target_scene_path: String, is_exiting: bool = false) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	transition_animation_player.play("fade_out")
	await transition_animation_player.animation_finished

	if is_exiting:
		get_tree().quit()
	elif target_scene_path:
		var error_code = get_tree().change_scene_to_file(target_scene_path)
		if error_code != OK:
			push_error("Failed to change scene to: " + target_scene_path + " Error code: " + str(error_code))
			# 如果加载失败，尝试淡入回来
			transition_animation_player.play("fade_in")
			_is_transitioning = false
	else: # 如果没有目标场景也不是退出（例如，只是关闭子菜单后不需要场景切换）
		_is_transitioning = false
		# 如果不是要切换场景，但调用了这个函数，可能需要一个淡入回到当前菜单
		# transition_animation_player.play("fade_in") # 取决于逻辑

# --- 音频 ---
func _play_hover_sound() -> void:
	if button_hover_sound and button_hover_sound.stream:
		button_hover_sound.play()

func _play_click_sound() -> void:
	if button_click_sound and button_click_sound.stream:
		button_click_sound.play()

# --- 特定逻辑 ---
func _update_load_button_state() -> void:
	# 这里需要你的存档系统逻辑来判断是否有存档
	# 例如: var save_exists = SaveSystem.has_any_save_file()
	var save_exists = false # 默认为false，你需要实现存档检查
	# 简单示例：检查 "user://saves/" 目录是否存在且不为空
	var dir = DirAccess.open("user://saves/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".save"): # 假设存档以.save结尾
				save_exists = true
				break
			file_name = dir.get_next()
		dir.list_dir_end()

	load_button.disabled = not save_exists
	load_button.tooltip_text = "没有可加载的存档" if not save_exists else ""


func _on_load_game_selected_from_submenu(_save_file_path: String) -> void:
	# 这个函数会被 LoadGameMenu 发出的信号调用
	# SaveSystem.current_save_to_load = save_file_path # 告诉存档系统要加载哪个文件
	_close_current_submenu() # 先关闭加载菜单
	await get_tree().create_timer(0.1).timeout # 短暂延迟确保关闭动画可能播放完毕
	_start_scene_transition("res://scenes/levels/your_game_scene_loader.tscn") # 或者直接加载游戏主场景，让它自己处理存档加载
