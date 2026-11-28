class_name ChannelSession
extends Node

## Одна активная сессия канала: чат, лобби, матч и всё общение с клиентами.
## Логика матча авторитетная: клиенты только показывают состояние и присылают команды.

signal state_changed
signal timer_tick(seconds: int)
signal event_fired(event_name: String, data: Dictionary)
signal notice(message: String)
signal closed

const MIN_PLAYERS := 3
const MIN_TURN_SECONDS := 5
const MAX_TURN_SECONDS := 600
const MIN_SHOP_SIZE := 1
const MAX_SHOP_SIZE := 8

## Паузы сервера под анимации клиента.
const ROUND_START_WAIT := 2.9
const PURCHASE_WAIT := 4.6
const SCORING_PRE_WAIT := 0.5
const SCORING_NET_BUFFER := 0.8
const ROUND_RESULTS_WAIT := 5.8
const NEXT_ROUND_PAUSE := 0.6
const GAME_OVER_WAIT := 3.0

const SCORE_START_HOLD := 0.6
const SCORE_STEP_TIME := 1.0
const SCORE_TEAM_HOLD := 1.0

var channel := ""
var max_players := 8
var turn_seconds := 60
var shop_size := 8
var phase := "lobby"
var players: Array[PlayerData] = []
var match_state: MatchState = null
var boosters: Array[BoosterData] = []
var clients: Dictionary = {}
var debug_enabled := false

var chat: TwitchChat = null

var _player_ids: Dictionary = {}
var _next_player_number := 1
var _chat_status := "connecting"
var _chat_error := ""
var _timer_left := 0
var _pending_command: Dictionary = {}
var _awaiting_command := false
var _game_generation := 0
var _placeholder_avatar: Texture2D = null


func _ready() -> void:
	_start_chat()


func _exit_tree() -> void:
	if chat != null:
		chat.disconnect_chat()


func add_client(peer_id: int) -> void:
	clients[peer_id] = true


func remove_client(peer_id: int) -> void:
	clients.erase(peer_id)


func has_clients() -> bool:
	return not clients.is_empty()


# --- Лобби и настройки -------------------------------------------------------

## Меняет настройки лобби. Сервер сам ограничивает диапазоны.
func set_settings(new_turn_seconds: int, new_shop_size: int) -> void:
	if phase != "lobby":
		return
	if new_turn_seconds > 0:
		turn_seconds = clampi(new_turn_seconds, MIN_TURN_SECONDS, MAX_TURN_SECONDS)
	if new_shop_size > 0:
		shop_size = clampi(new_shop_size, MIN_SHOP_SIZE, MAX_SHOP_SIZE)
	state_changed.emit()


## Запускает матч из лобби. Клиенты переключатся на игровую сцену по состоянию.
func start_match(new_turn_seconds: int = 0, new_shop_size: int = 0) -> void:
	if phase != "lobby":
		return
	if players.size() < MIN_PLAYERS:
		notice.emit("Для старта нужно минимум %d игрока." % MIN_PLAYERS)
		return
	if new_turn_seconds > 0:
		turn_seconds = clampi(new_turn_seconds, MIN_TURN_SECONDS, MAX_TURN_SECONDS)
	if new_shop_size > 0:
		shop_size = clampi(new_shop_size, MIN_SHOP_SIZE, MAX_SHOP_SIZE)
	match_state = MatchState.new()
	match_state.setup(players, boosters, shop_size)
	match_state.start_round()
	phase = "game"
	_game_generation += 1
	var generation := _game_generation
	_timer_left = 0
	_pending_command.clear()
	_awaiting_command = false
	print("SESSION #%s: старт матча, игроков %d, ход %d с, магазин %d" % [
		channel, players.size(), turn_seconds, shop_size,
	])
	state_changed.emit()
	event_fired.emit("round_start", {"round": match_state.round_number})
	_run_match(generation)


## Закрывает сессию: отключает чат и сообщает клиентам вернуться в main.
## Разрешено только из лобби (кнопка «Назад») и с экрана итогов
## (кнопка «Продолжить»); во время игры выйти можно только через !reset.
func close() -> void:
	if phase == "closed":
		return
	if phase != "lobby" and phase != "endgame":
		return
	_close_now()


## Принудительное закрытие для автоочистки: работает и во время матча.
func force_close() -> void:
	if phase == "closed":
		return
	_close_now()


func _close_now() -> void:
	_game_generation += 1
	phase = "closed"
	_awaiting_command = false
	if chat != null:
		chat.disconnect_chat()
	print("SESSION #%s: закрыта" % channel)
	closed.emit()
	queue_free()


# --- Состояние для клиентов --------------------------------------------------

func build_state() -> Dictionary:
	var serialized_players: Array = []
	for player in players:
		serialized_players.append(_serialize_player(player))
	return {
		"t": "state",
		"state": {
			"phase": phase,
			"channel": channel,
			"max_players": max_players,
			"turn_seconds": turn_seconds,
			"shop_size": shop_size,
			"chat": _chat_status,
			"chat_error": _chat_error,
			"players": serialized_players,
			"match": _serialize_match(),
		},
	}


func _serialize_player(player: PlayerData) -> Dictionary:
	return {
		"id": _player_id(player),
		"nickname": player.nickname,
		"login": player.twitch_login,
		"team": player.team,
		"coins": player.coins,
		"wins": player.wins,
		"boosters": player.boosters.duplicate(),
		"turn": player.turn_number,
		"excluded": player.turn_excluded,
		"color": NetProtocol.color_to_hex(player.nick_color),
		"avatar": player.avatar != null,
		"avatar_index": player.avatar_index,
	}


func _serialize_match() -> Dictionary:
	if match_state == null:
		return {}
	var shop_ids: Array = []
	for booster in match_state.shop:
		shop_ids.append(booster.id if booster != null else "")
	var order: Array = []
	for player in match_state.turn_order:
		order.append(_player_id(player))
	var current := match_state.get_current_player()
	var winner := match_state.game_winner
	return {
		"round": match_state.round_number,
		"phase": _match_phase_name(match_state.phase),
		"current": _player_id(current) if current != null else "",
		"order": order,
		"turn_index": match_state.turn_index,
		"timer": _timer_left,
		"shop": shop_ids,
		"score1": int(match_state.team_scores.get(1, MatchState.START_SCORE)),
		"score2": int(match_state.team_scores.get(2, MatchState.START_SCORE)),
		"last_player": _player_id(match_state.last_purchase_player) if match_state.last_purchase_player != null else "",
		"last_index": match_state.last_purchase_index,
		"winner": _player_id(winner) if winner != null else "",
		"resolved": match_state.round_resolved,
		"draw": match_state.is_draw,
		"game_over": match_state.phase == MatchState.Phase.GAME_OVER,
	}


func _match_phase_name(match_phase: int) -> String:
	match match_phase:
		MatchState.Phase.PURCHASE:
			return "purchase"
		MatchState.Phase.SCORING:
			return "scoring"
		_:
			return "game_over"


func _player_id(player: PlayerData) -> String:
	if player == null:
		return ""
	return str(_player_ids.get(player, ""))


# --- Чат ---------------------------------------------------------------------

func _start_chat() -> void:
	chat = TwitchChat.new()
	chat.name = "TwitchChat"
	add_child(chat)
	chat.chat_connected.connect(_on_chat_connected)
	chat.chat_message.connect(_on_chat_message)
	chat.chat_disconnected.connect(_on_chat_disconnected)
	chat.chat_error.connect(_on_chat_error)
	chat.connect_to_channel(channel)


func _on_chat_connected() -> void:
	_chat_status = "connected"
	_chat_error = ""
	print("SESSION #%s: чат подключён" % channel)
	state_changed.emit()


func _on_chat_disconnected() -> void:
	_chat_status = "disconnected"
	print("SESSION #%s: чат потерян" % channel)
	state_changed.emit()


func _on_chat_error(message: String) -> void:
	_chat_status = "error"
	_chat_error = message
	print("SESSION #%s: ошибка чата: %s" % [channel, message])
	state_changed.emit()


func _on_chat_message(login: String, display_name: String, user_id: String, text: String) -> void:
	var command := text.strip_edges()
	if phase == "lobby":
		if command.to_lower() == "!join":
			_add_player(login, display_name, user_id)
		return
	if phase != "game":
		return
	# Стример может вернуть игру в лобби в любой момент игровой сцены.
	if command.to_lower() == "!reset" and _is_streamer(login):
		_reset_to_lobby()
		return
	if not _awaiting_command or match_state == null:
		return
	if match_state.phase != MatchState.Phase.PURCHASE:
		return
	var player := match_state.get_current_player()
	if player == null or not _is_player_message(player, login, user_id):
		return
	if command == "!0":
		_pending_command = {"type": "skip"}
		_awaiting_command = false
		print("SESSION #%s: %s пропускает ход (!0)" % [channel, player.nickname])
		return
	if command.length() != 2 or not command.begins_with("!"):
		return
	var digit := command.substr(1)
	if not digit.is_valid_int():
		return
	var slot_number := int(digit)
	if slot_number < 1 or slot_number > match_state.shop.size():
		return
	var slot_index := slot_number - 1
	if not match_state.can_buy_slot(slot_index):
		return
	_pending_command = {"type": "buy", "slot": slot_index}
	_awaiting_command = false
	print("SESSION #%s: %s покупает !%d" % [channel, player.nickname, slot_number])


func _add_player(login: String, display_name: String, user_id: String) -> void:
	if phase != "lobby" or players.size() >= max_players:
		return
	var identity := user_id.strip_edges()
	if identity.is_empty():
		identity = login.strip_edges().to_lower()
	if identity.is_empty():
		return
	for existing in players:
		if existing.twitch_id == identity:
			return
	var nickname := display_name.strip_edges()
	if nickname.is_empty():
		nickname = login
	var player := PlayerData.new()
	player.twitch_id = identity
	player.twitch_login = login.strip_edges().to_lower()
	player.nickname = nickname
	# Аватар выдаётся по порядку подключения: 1-й — avatar_1, 2-й — avatar_2 и т.д.
	# Сервер не рендерит аватары: клиент сам загрузит нужную текстуру по номеру.
	var avatar_index := players.size() + 1
	player.avatar_index = avatar_index
	player.avatar = _get_placeholder_avatar()
	players.append(player)
	var player_id := "p%d" % _next_player_number
	_next_player_number += 1
	_player_ids[player] = player_id
	print("SESSION #%s: %s вошёл в лобби (%d/%d)" % [channel, nickname, players.size(), max_players])
	state_changed.emit()


## Серверу не нужны настоящие текстуры аватаров: в состояние отправляется
## только флаг наличия аватара и avatar_index, а клиент загружает текстуру сам.
func _get_placeholder_avatar() -> Texture2D:
	if _placeholder_avatar == null:
		var placeholder := PlaceholderTexture2D.new()
		placeholder.size = Vector2i(1, 1)
		_placeholder_avatar = placeholder
	return _placeholder_avatar


func _is_streamer(login: String) -> bool:
	if channel.is_empty():
		return false
	return login.strip_edges().to_lower() == channel


func _is_player_message(player: PlayerData, login: String, user_id: String) -> bool:
	var uid := user_id.strip_edges()
	if not uid.is_empty() and player.twitch_id == uid:
		return true
	var login_lower := login.strip_edges().to_lower()
	if not player.twitch_login.is_empty():
		return player.twitch_login == login_lower
	return player.twitch_id == login_lower


## Возврат в лобби по команде стримера: игроки и настройки сохраняются.
func _reset_to_lobby() -> void:
	if phase != "game":
		return
	_game_generation += 1
	phase = "lobby"
	match_state = null
	_timer_left = 0
	_pending_command.clear()
	_awaiting_command = false
	print("SESSION #%s: !reset, возврат в лобби" % channel)
	state_changed.emit()


# --- Матч --------------------------------------------------------------------

func _run_match(generation: int) -> void:
	if not await _wait(ROUND_START_WAIT, generation):
		return
	while generation == _game_generation and match_state != null:
		if match_state.phase == MatchState.Phase.PURCHASE:
			await _play_turn(generation)
		elif match_state.phase == MatchState.Phase.SCORING:
			await _resolve_round(generation)
		else:
			await _finish_game(generation)
			return


func _play_turn(generation: int) -> void:
	var player := match_state.get_current_player()
	if player == null:
		return
	_pending_command.clear()
	_awaiting_command = true
	_timer_left = turn_seconds
	state_changed.emit()
	var left := float(turn_seconds)
	var shown := turn_seconds
	while left > 0.0:
		if generation != _game_generation:
			return
		if not _pending_command.is_empty():
			break
		if not await _wait(0.1, generation):
			return
		left -= 0.1
		var next_shown := int(ceil(maxf(left, 0.0)))
		if next_shown != shown:
			shown = next_shown
			_timer_left = next_shown
			timer_tick.emit(next_shown)
	_awaiting_command = false
	_timer_left = 0
	var action := _pending_command
	_pending_command = {}
	if action.is_empty():
		action = {"type": "timeout"}
	await _execute_turn(action, generation)


func _execute_turn(action: Dictionary, generation: int) -> void:
	var player := match_state.get_current_player()
	if player == null:
		return
	var round_number := match_state.round_number
	var turn_number := match_state.turn_index + 1
	var action_type := str(action.get("type", "timeout"))
	var slot := -1
	match action_type:
		"buy":
			slot = int(action.get("slot", -1))
		"skip":
			pass
		"timeout":
			slot = match_state.find_random_affordable_slot()
		_:
			slot = match_state.find_first_affordable_slot()
	if action_type == "skip" or slot < 0:
		print("R%d T%d: %s пропускает (монеты %d)" % [round_number, turn_number, player.nickname, player.coins])
		match_state.skip_turn()
		_timer_left = turn_seconds if match_state.phase == MatchState.Phase.PURCHASE else 0
		state_changed.emit()
		return
	var shop_booster: BoosterData = match_state.shop[slot]
	if not match_state.buy_from_slot(slot):
		print("R%d T%d: %s пропускает (покупка отклонена)" % [round_number, turn_number, player.nickname])
		match_state.skip_turn()
		_timer_left = turn_seconds if match_state.phase == MatchState.Phase.PURCHASE else 0
		state_changed.emit()
		return
	var acquired_id := match_state.get_last_purchase_booster_id()
	var target_index := match_state.get_last_purchase_index(player)
	print("R%d T%d: %s покупает %s (монеты %d)%s" % [
		round_number,
		turn_number,
		player.nickname,
		shop_booster.display_name,
		player.coins,
		" (timeout)" if action_type == "timeout" else "",
	])
	event_fired.emit("purchase", {
		"buyer": _player_id(player),
		"shop_slot": slot,
		"shop_booster": shop_booster.id,
		"acquired": acquired_id,
		"target_index": target_index,
		"timeout": action_type == "timeout",
	})
	if not await _wait(PURCHASE_WAIT, generation):
		return
	_timer_left = turn_seconds if match_state.phase == MatchState.Phase.PURCHASE else 0
	state_changed.emit()


func _resolve_round(generation: int) -> void:
	var result := match_state.finish_round()
	if result.is_empty():
		return
	_timer_left = 0
	state_changed.emit()
	if not await _wait(SCORING_PRE_WAIT, generation):
		return
	event_fired.emit("scoring", _serialize_result(result))
	var wait_time := _scoring_duration(result) + SCORING_NET_BUFFER
	if not await _wait(wait_time, generation):
		return
	event_fired.emit("round_results", _serialize_result(result))
	if not await _wait(ROUND_RESULTS_WAIT, generation):
		return
	if bool(result.get("game_over", false)):
		return
	if not await _wait(NEXT_ROUND_PAUSE, generation):
		return
	match_state.start_round()
	state_changed.emit()
	event_fired.emit("round_start", {"round": match_state.round_number})
	if not await _wait(ROUND_START_WAIT, generation):
		return


func _finish_game(generation: int) -> void:
	print("SESSION #%s: игра окончена, победитель: %s" % [
		channel,
		match_state.game_winner.nickname if match_state != null and match_state.game_winner != null else "—",
	])
	if not await _wait(GAME_OVER_WAIT, generation):
		return
	phase = "endgame"
	_timer_left = 0
	state_changed.emit()


## Сколько клиент будет проигрывать поп-ап подсчёта очков обеих команд.
func _scoring_duration(result: Dictionary) -> float:
	if match_state == null:
		return 0.0
	var duration := 0.0
	var correction_team := int(result.get("correction_team", 0))
	var correction_multiplier := float(result.get("correction_multiplier", 1.0))
	var bonuses_by_player: Dictionary = result.get("booster_bonuses", {})
	for team in [1, 2]:
		duration += SCORE_START_HOLD
		var cumulative := 1.0
		for player in match_state.get_team_players_in_turn_order(team):
			var bonuses: Array = bonuses_by_player.get(player, [])
			for index in player.boosters.size():
				if player.boosters[index].is_empty():
					continue
				var bonus := float(bonuses[index]) if index < bonuses.size() else 0.0
				cumulative *= 1.0 + bonus / 100.0
				duration += SCORE_STEP_TIME
		var animated := roundi(float(MatchState.START_SCORE) * cumulative)
		if correction_team == team:
			var corrected := roundi(float(MatchState.START_SCORE) * cumulative * correction_multiplier)
			if corrected != animated:
				duration += SCORE_STEP_TIME
			animated = corrected
		var target := int(result.get("team1_score" if team == 1 else "team2_score", MatchState.START_SCORE))
		if animated != target:
			duration += SCORE_STEP_TIME
		duration += SCORE_TEAM_HOLD
	return duration


func _serialize_result(result: Dictionary) -> Dictionary:
	var winner_ids: Array = []
	for player in result.get("winners", []):
		winner_ids.append(_player_id(player))
	var loser_ids: Array = []
	for player in result.get("losers", []):
		loser_ids.append(_player_id(player))
	var changes: Dictionary = {}
	var changes_in: Dictionary = result.get("player_changes", {})
	for player in changes_in.keys():
		changes[_player_id(player)] = changes_in[player]
	var bonuses: Dictionary = {}
	var bonuses_in: Dictionary = result.get("booster_bonuses", {})
	for player in bonuses_in.keys():
		bonuses[_player_id(player)] = bonuses_in[player]
	var winner: PlayerData = result.get("game_winner", null)
	return {
		"team1_score": int(result.get("team1_score", MatchState.START_SCORE)),
		"team2_score": int(result.get("team2_score", MatchState.START_SCORE)),
		"draw": bool(result.get("draw", false)),
		"winners": winner_ids,
		"losers": loser_ids,
		"changes": changes,
		"bonuses": bonuses,
		"correction_team": int(result.get("correction_team", 0)),
		"correction_percent": float(result.get("correction_percent", 0.0)),
		"correction_multiplier": float(result.get("correction_multiplier", 1.0)),
		"game_over": bool(result.get("game_over", false)),
		"winner": _player_id(winner) if winner != null else "",
	}


func _wait(seconds: float, generation: int) -> bool:
	var left := seconds
	while left > 0.0:
		if generation != _game_generation:
			return false
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step
	return generation == _game_generation


# --- Отладочные команды (только с --debug на сервере) ------------------------

func debug_add_player(login: String, display_name: String, user_id: String) -> void:
	if not debug_enabled:
		return
	_add_player(login, display_name, user_id)


func debug_say(login: String, display_name: String, user_id: String, text: String) -> void:
	if not debug_enabled:
		return
	_on_chat_message(login, display_name, user_id, text)
