extends Node

## Переключает сцены онлайн-клиента по фазе, которую прислал сервер:
## лобби → игра → конец игры. В локальном режиме ничего не делает.

const MAIN_SCENE := "res://scenes/main.tscn"
const LOBBY_SCENE := "res://scenes/lobby.tscn"
const GAME_SCENE := "res://scenes/game.tscn"
const ENDGAME_SCENE := "res://scenes/endgame.tscn"

var _switching := false


func _ready() -> void:
	NetworkClient.state_received.connect(_on_state_received)
	NetworkClient.session_closed.connect(_on_session_closed)


func _on_state_received(new_state: Dictionary) -> void:
	if not NetworkClient.is_online():
		return
	var target := ""
	match str(new_state.get("phase", "")):
		"lobby":
			target = LOBBY_SCENE
		"game":
			target = GAME_SCENE
		"endgame":
			target = ENDGAME_SCENE
	if target.is_empty():
		return
	_change_scene(target)


func _on_session_closed() -> void:
	if not NetworkClient.is_online():
		return
	_change_scene(MAIN_SCENE)


func _change_scene(path: String) -> void:
	if _switching:
		return
	var current := get_tree().current_scene
	if current != null and current.scene_file_path == path:
		return
	_switching = true
	get_tree().call_deferred("change_scene_to_file", path)
	await get_tree().process_frame
	await get_tree().process_frame
	_switching = false
	# Пока шла смена сцены, могло прийти новое состояние.
	if not NetworkClient.state.is_empty():
		var target := ""
		match str(NetworkClient.state.get("phase", "")):
			"lobby":
				target = LOBBY_SCENE
			"game":
				target = GAME_SCENE
			"endgame":
				target = ENDGAME_SCENE
		if not target.is_empty():
			var scene := get_tree().current_scene
			if scene == null or scene.scene_file_path != target:
				_change_scene(target)
