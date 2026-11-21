extends Node2D

## Контроллер игры: запускает матч из лобби (игроки, таймер, магазин)
## или демо-матч при прямом запуске сцены.

const PLAYERS_COUNT := 8
const BOOSTERS_DIR := "res://resources/boosters"
const SHOP_SIZE := 8
const TURN_DELAY := 2.0
const DEFAULT_TURN_SECONDS := 60
const MIN_TURN_SECONDS := 5
const MAX_TURN_SECONDS := 600
const SCORING_PRE_DELAY := 0.5
const SCORING_DELAY := 2.0
const ROUND_DELAY := 0.8
const SCORE_START_HOLD := 0.6
const SCORE_STEP_TIME := 1.0
const SCORE_TEAM_HOLD := 1.0
const GAME_OVER_HOLD := 3.0
## Пауза после приземления иконки, перед поп-апом покупки.
const PURCHASE_LANDING_HOLD := 0.18
const PURCHASE_FALLBACK_COLOR := Color(0.686, 0.416, 1.0, 1.0)
const ENDGAME_SCENE := "res://scenes/endgame.tscn"
const LOBBY_SCENE := "res://scenes/lobby.tscn"

var _match := MatchState.new()
var _autoplay_running := false
## Матч запущен из лобби: играем игроками из SessionConfig и по таймеру хода.
var _from_lobby := false
## Длительность хода в секундах для матча из лобби.
var _turn_seconds := DEFAULT_TURN_SECONDS
## Размер магазина для матча из лобби (1–8).
var _shop_size := SHOP_SIZE
## 0 — играть до конца, иначе остановиться после указанного раунда (для записи).
var _stop_after_round := 0
## Сколько демо-игроков брать в матч (по умолчанию все 8; для записи можно задать меньше).
var _players_count := PLAYERS_COUNT
## Задержка перед ходом автопилота; можно переопределить аргументом --turn-delay=N.
var _turn_delay := TURN_DELAY
## Ждём команду текущего игрока из чата.
var _awaiting_command := false
## Команда, принятая от чата: {"type": "buy", "slot": N} или {"type": "skip"}.
var _pending_command: Dictionary = {}
## Идёт возврат в лобби по команде стримера !reset.
var _resetting := false

@onready var _round_number: Label = $UILayer/Root/Zones/TopZone/InfoWindow/Content/InfoContent/TopRow/RoundCell/RoundNumber
@onready var _timer_label: Label = $UILayer/Root/Zones/TopZone/InfoWindow/Content/InfoContent/TopRow/TimerCell/TimerLabel
@onready var _turn_label: Label = $UILayer/Root/Zones/TopZone/InfoWindow/Content/InfoContent/TurnLabel
@onready var _player_name: Label = $UILayer/Root/Zones/TopZone/InfoWindow/Content/InfoContent/PlayerName
@onready var _order_slots: Array = [
	$UILayer/Root/Zones/TopZone/OrderWindow/Content/OrderContent/SlotsRow/Slot1,
	$UILayer/Root/Zones/TopZone/OrderWindow/Content/OrderContent/SlotsRow/Slot2,
	$UILayer/Root/Zones/TopZone/OrderWindow/Content/OrderContent/SlotsRow/Slot3,
	$UILayer/Root/Zones/TopZone/OrderWindow/Content/OrderContent/SlotsRow/Slot4,
	$UILayer/Root/Zones/TopZone/OrderWindow/Content/OrderContent/SlotsRow/Slot5,
	$UILayer/Root/Zones/TopZone/OrderWindow/Content/OrderContent/SlotsRow/Slot6,
	$UILayer/Root/Zones/TopZone/OrderWindow/Content/OrderContent/SlotsRow/Slot7,
	$UILayer/Root/Zones/TopZone/OrderWindow/Content/OrderContent/SlotsRow/Slot8,
]
@onready var _shop_slots: Array = [
	$UILayer/Root/Zones/SecondZone/ShopWindow/Content/ShopContent/SlotsRow/Booster1,
	$UILayer/Root/Zones/SecondZone/ShopWindow/Content/ShopContent/SlotsRow/Booster2,
	$UILayer/Root/Zones/SecondZone/ShopWindow/Content/ShopContent/SlotsRow/Booster3,
	$UILayer/Root/Zones/SecondZone/ShopWindow/Content/ShopContent/SlotsRow/Booster4,
	$UILayer/Root/Zones/SecondZone/ShopWindow/Content/ShopContent/SlotsRow/Booster5,
	$UILayer/Root/Zones/SecondZone/ShopWindow/Content/ShopContent/SlotsRow/Booster6,
	$UILayer/Root/Zones/SecondZone/ShopWindow/Content/ShopContent/SlotsRow/Booster7,
	$UILayer/Root/Zones/SecondZone/ShopWindow/Content/ShopContent/SlotsRow/Booster8,
]
@onready var _team1_cards: Array = [
	$UILayer/Root/Zones/MiddleZone/Team1Window/Content/CardsRow/Player1,
	$UILayer/Root/Zones/MiddleZone/Team1Window/Content/CardsRow/Player2,
	$UILayer/Root/Zones/MiddleZone/Team1Window/Content/CardsRow/Player3,
	$UILayer/Root/Zones/MiddleZone/Team1Window/Content/CardsRow/Player4,
]
@onready var _team2_cards: Array = [
	$UILayer/Root/Zones/MiddleZone/Team2Window/Content/CardsRow/Player1,
	$UILayer/Root/Zones/MiddleZone/Team2Window/Content/CardsRow/Player2,
	$UILayer/Root/Zones/MiddleZone/Team2Window/Content/CardsRow/Player3,
	$UILayer/Root/Zones/MiddleZone/Team2Window/Content/CardsRow/Player4,
]
@onready var _team1_score: TeamScoreFrame = $UILayer/Root/Zones/BottomZone/Team1Frame as TeamScoreFrame
@onready var _team2_score: TeamScoreFrame = $UILayer/Root/Zones/BottomZone/Team2Frame as TeamScoreFrame
@onready var _purchase_popup: PurchasePopup = $UILayer/Root/PurchasePopup as PurchasePopup
@onready var _purchase_flight: PurchaseFlight = $UILayer/Root/PurchaseFlight as PurchaseFlight
@onready var _score_popup: ScorePopup = $UILayer/Root/ScorePopup as ScorePopup
@onready var _round_results_popup: RoundResultsPopup = $UILayer/Root/RoundResultsPopup as RoundResultsPopup
@onready var _round_start_popup: RoundStartPopup = $UILayer/Root/RoundStartPopup as RoundStartPopup


func _ready() -> void:
	_stop_after_round = _read_stop_after_round()
	_players_count = _read_players_count()
	_turn_delay = _read_turn_delay()
	_from_lobby = not SessionConfig.players.is_empty()
	# Чат — общий autoload, поэтому он переживает переход из лобби в игру.
	if not ChatService.chat_message.is_connected(_on_chat_message):
		ChatService.chat_message.connect(_on_chat_message)
	if not ChatService.chat_disconnected.is_connected(_on_chat_disconnected):
		ChatService.chat_disconnected.connect(_on_chat_disconnected)
	if not ChatService.chat_error.is_connected(_on_chat_error):
		ChatService.chat_error.connect(_on_chat_error)
	var players: Array[PlayerData] = []
	if _from_lobby:
		_turn_seconds = clampi(SessionConfig.turn_seconds, MIN_TURN_SECONDS, MAX_TURN_SECONDS)
		_shop_size = clampi(SessionConfig.shop_size, 1, SHOP_SIZE)
		players.assign(SessionConfig.players)
	else:
		players = _load_players()
	var boosters := _load_boosters()
	if players.is_empty():
		push_error("Game: не удалось загрузить игроков")
		return
	if boosters.is_empty():
		push_error("Game: не удалось загрузить бустеры")
		return
	_match.setup(players, boosters, _shop_size)
	_match.start_round()
	_update_ui()
	if _from_lobby:
		print("MATCH START: players=%d boosters=%d turn=%ds shop=%d (lobby)" % [players.size(), boosters.size(), _turn_seconds, _shop_size])
	else:
		print("MATCH START: players=%d boosters=%d turn_delay=%.1f" % [players.size(), boosters.size(), _turn_delay])
	await _show_round_start()
	if not is_inside_tree():
		return
	_autoplay_running = true
	_autoplay_loop()


func _exit_tree() -> void:
	_autoplay_running = false
	_awaiting_command = false
	if ChatService.chat_message.is_connected(_on_chat_message):
		ChatService.chat_message.disconnect(_on_chat_message)
	if ChatService.chat_disconnected.is_connected(_on_chat_disconnected):
		ChatService.chat_disconnected.disconnect(_on_chat_disconnected)
	if ChatService.chat_error.is_connected(_on_chat_error):
		ChatService.chat_error.disconnect(_on_chat_error)


func _autoplay_loop() -> void:
	while _autoplay_running:
		if _match.is_game_over():
			_update_ui()
			print("GAME OVER: winner=%s" % (_match.game_winner.nickname if _match.game_winner != null else "—"))
			await get_tree().create_timer(GAME_OVER_HOLD).timeout
			if not _autoplay_running or not is_inside_tree():
				return
			if "--quit-on-game-over" in OS.get_cmdline_user_args():
				get_tree().quit()
				return
			MatchResults.match_state = _match
			get_tree().change_scene_to_file(ENDGAME_SCENE)
			return
		if _match.phase == MatchState.Phase.PURCHASE:
			_update_ui()
			var action: Dictionary = await _wait_for_turn()
			if not _autoplay_running or not is_inside_tree() or action.is_empty():
				return
			await _take_turn(action)
			if _match.phase == MatchState.Phase.SCORING:
				await _resolve_round()
		elif _match.phase == MatchState.Phase.SCORING:
			await _resolve_round()
		else:
			return


## Ждёт ход: в демо-режиме — фиксированная задержка, в матче из лобби —
## обратный отсчёт с приёмом команд чата. Возвращает действие:
## {"type": "buy", "slot": N}, {"type": "skip"}, {"type": "timeout"}
## или {"type": "demo"}.
func _wait_for_turn() -> Dictionary:
	if not _from_lobby:
		await get_tree().create_timer(_turn_delay).timeout
		return {"type": "demo"}
	var remaining := float(_turn_seconds)
	var shown := _turn_seconds
	_timer_label.text = _format_timer(shown)
	_pending_command.clear()
	_awaiting_command = true
	while remaining > 0.0:
		await get_tree().create_timer(0.1).timeout
		if not _autoplay_running or not is_inside_tree():
			_awaiting_command = false
			return {}
		# Команда пришла раньше таймера — сразу отменяем отсчёт.
		if not _pending_command.is_empty():
			_awaiting_command = false
			var action := _pending_command
			_pending_command = {}
			return action
		remaining -= 0.1
		var next_shown := int(ceil(maxf(remaining, 0.0)))
		if next_shown != shown:
			shown = next_shown
			_timer_label.text = _format_timer(shown)
	_awaiting_command = false
	return {"type": "timeout"}


func _take_turn(action: Dictionary) -> void:
	var player := _match.get_current_player()
	if player == null:
		return
	var round_number := _match.round_number
	var turn_number := _match.turn_index + 1
	var action_type: String = str(action.get("type", "timeout"))
	var turn_note := ""
	var slot := -1
	match action_type:
		"buy":
			slot = int(action.get("slot", -1))
		"skip":
			turn_note = " (!0)"
		"timeout":
			slot = _match.find_random_affordable_slot()
			turn_note = " (timeout)"
		_:
			slot = _match.find_first_affordable_slot()
	if action_type == "skip" or slot < 0:
		print("R%d T%d: %s skips (coins %d)%s" % [round_number, turn_number, player.nickname, player.coins, turn_note])
		_match.skip_turn()
		_update_ui()
		return
	var booster: BoosterData = _match.shop[slot]
	var shop_slot: BoosterSlotCard = _shop_slots[slot]
	var buyer_card := _find_player_card(player)
	if not _match.buy_from_slot(slot):
		print("R%d T%d: %s skips (buy rejected, coins %d)%s" % [round_number, turn_number, player.nickname, player.coins, turn_note])
		_match.skip_turn()
		_update_ui()
		return
	print("R%d T%d: %s buys %s (coins %d)%s" % [round_number, turn_number, player.nickname, booster.display_name, player.coins, turn_note])
	# Летит именно тот бустер, которым покупка стала после превращений
	# («Ртуть», «Мел», «Маска», «Ключ» и т. п.).
	var acquired: BoosterData = _match.catalog.get(_match.get_last_purchase_booster_id())
	if acquired == null:
		acquired = booster
	await _play_purchase_animation(
		shop_slot,
		buyer_card,
		player,
		acquired,
		_match.get_last_purchase_index(player),
	)
	if not _autoplay_running or not is_inside_tree():
		return
	# Поп-ап появляется только после приземления иконки и вспышки рамки.
	_purchase_popup.show_purchase(player.avatar, player.nickname, player.nick_color, booster.display_name, booster.icon, booster.description)
	# Не начинаем следующий ход, пока поп-ап не покажется полностью.
	await _purchase_popup.display_finished
	if not _autoplay_running or not is_inside_tree():
		return
	_update_ui()


## Анимация покупки: карточка магазина приподнимается и вспыхивает, иконка
## отделяется и летит по дуге в ячейку покупателя, там вспыхивает рамка.
func _play_purchase_animation(
	shop_slot: BoosterSlotCard,
	buyer_card: TeamPlayerCard,
	buyer: PlayerData,
	acquired: BoosterData,
	target_index: int,
) -> void:
	if shop_slot == null or acquired == null:
		return
	var from_rect := shop_slot.get_icon_global_rect()
	var has_cell := target_index >= 0 and buyer_card != null
	var to_rect := from_rect
	if buyer_card != null:
		if has_cell:
			to_rect = buyer_card.get_booster_cell_global_rect(target_index)
		else:
			to_rect = buyer_card.get_boosters_grid_global_rect()
	if to_rect.size == Vector2.ZERO:
		to_rect = Rect2(from_rect.position, from_rect.size)
	var price_color: Color = TeamPlayerCard.BOOSTER_PRICE_COLORS.get(acquired.price, PURCHASE_FALLBACK_COLOR)
	# Карточка магазина реагирует на покупку.
	var lift := shop_slot.play_purchase_lift()
	await lift.finished
	if not is_inside_tree():
		return
	# Иконка отрывается, карточка гаснет, и сразу начинается полёт.
	shop_slot.hide_icon_for_purchase()
	shop_slot.fade_out_for_purchase()
	# Ячейка-цель уже существует, но её иконка спрятана до приземления.
	if buyer_card != null and has_cell:
		_prepare_buyer_card(buyer_card, buyer, target_index)
	var flight_finished := _purchase_flight.finished
	_purchase_flight.play(acquired.icon, from_rect, to_rect, price_color)
	await flight_finished
	if not is_inside_tree():
		return
	# К этому моменту карточка магазина давно погасла.
	shop_slot.clear()
	if buyer_card != null:
		if has_cell:
			buyer_card.reveal_purchased_booster(target_index)
		else:
			# «Штамп-карта» и подобные бустеры не занимают отдельный слот:
			# обновляем карточку и показываем волну по всей сетке.
			_prepare_buyer_card(buyer_card, buyer, -1)
			buyer_card.play_purchase_wave()
	await get_tree().create_timer(PURCHASE_LANDING_HOLD).timeout


## Обновляет только карточку покупателя, не трогая окно хода и остальные зоны.
func _prepare_buyer_card(card: TeamPlayerCard, player: PlayerData, acquired_index: int) -> void:
	card.player = player
	card.booster_icons = _booster_icons_for(player)
	card.booster_prices = _booster_prices_for(player)
	card.highlighted_booster_index = -1
	if acquired_index >= 0:
		card.hide_booster_for_purchase(acquired_index)


## Находит карточку игрока в окнах команд по текущему составу.
func _find_player_card(player: PlayerData) -> TeamPlayerCard:
	for card in _team1_cards:
		if card.player == player:
			return card
	for card in _team2_cards:
		if card.player == player:
			return card
	return null


func _resolve_round() -> void:
	_update_ui()
	await get_tree().create_timer(SCORING_PRE_DELAY).timeout
	if not _autoplay_running or not is_inside_tree():
		return
	var result := _match.finish_round()
	if result.is_empty():
		return
	var correction_text := ""
	if int(result.get("correction_team", 0)) != 0:
		correction_text = " correction=Team%d +%.1f%%" % [
			int(result.get("correction_team", 0)),
			float(result.get("correction_percent", 0.0)),
		]
	print("Round %d: Team1=%d Team2=%d%s%s" % [
		_match.round_number,
		result.get("team1_score", MatchState.START_SCORE),
		result.get("team2_score", MatchState.START_SCORE),
		" (draw)" if result.get("draw", false) else "",
		correction_text,
	])
	await _play_score_popup(result)
	if not _autoplay_running or not is_inside_tree():
		return
	var winners: Array[PlayerData] = []
	winners.assign(result.get("winners", []))
	var losers: Array[PlayerData] = []
	losers.assign(result.get("losers", []))
	var changes: Dictionary = result.get("player_changes", {})
	_round_results_popup.show_results(winners, losers, changes)
	await _round_results_popup.display_finished
	if not _autoplay_running or not is_inside_tree():
		return
	_update_ui()
	if _stop_after_round > 0 and _match.round_number >= _stop_after_round:
		print("AUTOPLAY STOP: after round %d" % _match.round_number)
		await get_tree().create_timer(GAME_OVER_HOLD).timeout
		if is_inside_tree():
			get_tree().quit()
		return
	await get_tree().create_timer(SCORING_DELAY).timeout
	if not _autoplay_running or not is_inside_tree():
		return
	if _match.is_game_over():
		_update_ui()
		return
	_match.start_round()
	_update_ui()
	await _show_round_start()
	if not _autoplay_running or not is_inside_tree():
		return
	await get_tree().create_timer(ROUND_DELAY).timeout


## Показывает поп-ап «Раунд N» и ждёт его закрытия.
func _show_round_start() -> void:
	_round_start_popup.show_round(_match.round_number)
	await _round_start_popup.display_finished


## Показывает поп-ап подсчёта сначала для команды 1, затем для команды 2.
func _play_score_popup(result: Dictionary) -> void:
	_purchase_popup.hide_popup()
	var bonuses: Dictionary = result.get("booster_bonuses", {})
	await _play_team_score(1, result, bonuses)
	if not _autoplay_running or not is_inside_tree():
		return
	await _play_team_score(2, result, bonuses)
	if not _autoplay_running or not is_inside_tree():
		return
	_score_popup.hide_popup()


## Применяет бонусы команды по одному: процент становится зелёным,
## а счёт набегает до значения с учётом этого бустера.
func _play_team_score(team: int, result: Dictionary, bonuses_by_player: Dictionary) -> void:
	var team_players := _match.get_team_players_in_turn_order(team)
	_score_popup.set_team_players(team_players, _match.catalog, bonuses_by_player)
	_score_popup.show_team(team)
	var correction_team := int(result.get("correction_team", 0))
	var has_correction := correction_team == team
	var correction_percent := float(result.get("correction_percent", 0.0))
	var correction_multiplier := float(result.get("correction_multiplier", 1.0))
	if has_correction:
		_score_popup.set_correction(true, correction_percent, correction_multiplier)
	# Даём увидеть исходное состояние: 1 000 000 и все проценты белые.
	await get_tree().create_timer(SCORE_START_HOLD).timeout
	if not _autoplay_running or not is_inside_tree():
		return
	var base := float(MatchState.START_SCORE)
	var cumulative := 1.0
	for column_index in team_players.size():
		var player: PlayerData = team_players[column_index]
		var player_bonuses: Array = bonuses_by_player.get(player, [])
		for booster_index in player.boosters.size():
			# Пустой слот (бустер украден «Ключом») не показывается и не считается.
			if player.boosters[booster_index].is_empty():
				continue
			var bonus := float(player_bonuses[booster_index]) if booster_index < player_bonuses.size() else 0.0
			cumulative *= 1.0 + bonus / 100.0
			_score_popup.mark_bonus_applied(column_index, booster_index)
			var step_tween := _score_popup.animate_score(roundi(base * cumulative), SCORE_STEP_TIME)
			await step_tween.finished
			if not _autoplay_running or not is_inside_tree():
				return
	var animated_score := roundi(base * cumulative)
	if has_correction:
		_score_popup.mark_correction_applied()
		var corrected_score := roundi(base * cumulative * correction_multiplier)
		if corrected_score != animated_score:
			var correction_tween := _score_popup.animate_score(corrected_score, SCORE_STEP_TIME)
			await correction_tween.finished
			if not _autoplay_running or not is_inside_tree():
				return
		animated_score = corrected_score
	var target := int(result.get("team1_score" if team == 1 else "team2_score", MatchState.START_SCORE))
	if animated_score != target:
		var final_tween := _score_popup.animate_score(target, SCORE_STEP_TIME)
		await final_tween.finished
	if team == 1:
		_team1_score.score = target
	else:
		_team2_score.score = target
	await get_tree().create_timer(SCORE_TEAM_HOLD).timeout


func _update_ui() -> void:
	_round_number.text = str(max(1, _match.round_number))
	# В матче из лобби таймер стартует с полной длительности хода.
	if _from_lobby and _match.phase == MatchState.Phase.PURCHASE:
		_timer_label.text = _format_timer(_turn_seconds)
	else:
		_timer_label.text = "00"
	_update_info()
	_update_order_slots()
	_update_team_cards()
	_update_shop()
	_update_scores()


func _format_timer(seconds: int) -> String:
	return "%02d" % maxi(0, seconds)


func _update_info() -> void:
	if _match.is_game_over():
		_turn_label.text = "ПОБЕДИТЕЛЬ"
		var winner := _match.game_winner
		_player_name.text = winner.nickname if winner != null else "—"
		_player_name.add_theme_color_override("font_color", winner.nick_color if winner != null else Color.WHITE)
		return
	if _match.phase == MatchState.Phase.SCORING:
		if _match.round_resolved:
			if _match.is_draw:
				_turn_label.text = "НИЧЬЯ"
			else:
				var winning_team := 1 if _match.team_scores[1] > _match.team_scores[2] else 2
				_turn_label.text = "ПОБЕДА КОМАНДЫ %d" % winning_team
		else:
			_turn_label.text = "ПОДСЧЁТ ОЧКОВ"
		_player_name.text = "—"
		_player_name.add_theme_color_override("font_color", Color.WHITE)
		return
	_turn_label.text = "ХОД ИГРОКА"
	var current := _match.get_current_player()
	_player_name.text = current.nickname if current != null else "—"
	_player_name.add_theme_color_override("font_color", current.nick_color if current != null else Color.WHITE)


func _update_order_slots() -> void:
	for index in _order_slots.size():
		var slot = _order_slots[index]
		if index < _match.turn_order.size():
			var player: PlayerData = _match.turn_order[index]
			slot.visible = true
			slot.modulate.a = 1.0
			slot.player = player
			slot.active = _match.phase == MatchState.Phase.PURCHASE and index == _match.turn_index
			# В свой ход аватар цветной, у остальных ЧБ. Во время подсчёта
			# очков активного игрока нет — все остаются цветными.
			slot.avatar_grayscale = _match.phase == MatchState.Phase.PURCHASE and index != _match.turn_index
		else:
			# Слот остаётся в ряду прозрачным: карточки игроков сохраняют
			# свою ширину, а на месте выбывших остаётся пустое место.
			slot.clear()
			slot.visible = true
			slot.modulate.a = 0.0


func _update_team_cards() -> void:
	_fill_team_cards(_team1_cards, _match.get_team_players_in_turn_order(1))
	_fill_team_cards(_team2_cards, _match.get_team_players_in_turn_order(2))


func _fill_team_cards(cards: Array, team_players: Array[PlayerData]) -> void:
	for index in cards.size():
		var card = cards[index]
		if index < team_players.size():
			var player: PlayerData = team_players[index]
			card.visible = true
			card.player = player
			card.booster_icons = _booster_icons_for(player)
			card.booster_prices = _booster_prices_for(player)
			card.highlighted_booster_index = _match.get_last_purchase_index(player)
			card.active = player == _match.get_current_player()
		else:
			card.clear()
			card.visible = false


func _booster_icons_for(player: PlayerData) -> Array[Texture2D]:
	var icons: Array[Texture2D] = []
	for booster_id in player.boosters:
		var data: BoosterData = _match.catalog.get(booster_id)
		icons.append(data.icon if data != null else null)
	return icons


func _booster_prices_for(player: PlayerData) -> Array[int]:
	var prices: Array[int] = []
	for booster_id in player.boosters:
		var data: BoosterData = _match.catalog.get(booster_id)
		prices.append(data.price if data != null else 0)
	return prices


func _update_shop() -> void:
	for index in _shop_slots.size():
		var slot = _shop_slots[index]
		slot.booster_number = index + 1
		var booster: BoosterData = _match.shop[index] if index < _match.shop.size() else null
		if booster != null:
			slot.show_card()
			slot.booster = booster
		else:
			slot.clear()


func _update_scores() -> void:
	_team1_score.score = int(_match.team_scores.get(1, MatchState.START_SCORE))
	_team2_score.score = int(_match.team_scores.get(2, MatchState.START_SCORE))


## Читает --stop-after-round=N из аргументов после «--».
func _read_stop_after_round() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stop-after-round="):
			return max(0, int(arg.get_slice("=", 1)))
	return 0


## Читает --players=N из аргументов после «--» (от 3 до 8).
func _read_players_count() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--players="):
			return clampi(int(arg.get_slice("=", 1)), 3, PLAYERS_COUNT)
	return PLAYERS_COUNT


## Читает --turn-delay=SECONDS из аргументов после «--».
func _read_turn_delay() -> float:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--turn-delay="):
			return clampf(float(arg.get_slice("=", 1)), 0.5, 30.0)
	return TURN_DELAY


func _load_players() -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	for index in _players_count:
		var path := "res://resources/players/player_%d.tres" % (index + 1)
		var resource := load(path) as PlayerData
		if resource == null:
			push_warning("Player resource not found: %s" % path)
			continue
		var player := resource.duplicate(true) as PlayerData
		if player != null:
			result.append(player)
	return result


func _load_boosters() -> Array[BoosterData]:
	var result: Array[BoosterData] = []
	var dir := DirAccess.open(BOOSTERS_DIR)
	if dir == null:
		push_error("Booster directory not found: %s" % BOOSTERS_DIR)
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var resource := load(BOOSTERS_DIR + "/" + file_name) as BoosterData
			if resource != null:
				result.append(resource)
			else:
				push_warning("Not a BoosterData resource: %s" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a: BoosterData, b: BoosterData) -> bool: return a.id < b.id)
	return result


## Принимает команды из чата: !reset от стримера (логин совпадает с каналом)
## в любой момент игры, а !1–!8 и !0 — только от текущего игрока в его ход.
func _on_chat_message(login: String, display_name: String, user_id: String, text: String) -> void:
	if _from_lobby and not _resetting and text.strip_edges().to_lower() == "!reset" and _is_streamer(login):
		_reset_to_lobby()
		return
	if not _from_lobby or not _awaiting_command:
		return
	if _match.phase != MatchState.Phase.PURCHASE:
		return
	var player := _match.get_current_player()
	if player == null or not _is_current_player_message(player, login, user_id):
		return
	var command := text.strip_edges()
	if command == "!0":
		_pending_command = {"type": "skip"}
		_awaiting_command = false
		print("CHAT: %s skips (!0)" % player.nickname)
		return
	if command.length() != 2 or not command.begins_with("!"):
		return
	var digit := command.substr(1)
	if not digit.is_valid_int():
		return
	var slot_number := int(digit)
	if slot_number < 1 or slot_number > _match.shop.size():
		return
	var slot_index := slot_number - 1
	if not _match.can_buy_slot(slot_index):
		return
	_pending_command = {"type": "buy", "slot": slot_index}
	_awaiting_command = false
	print("CHAT: %s buys !%d" % [player.nickname, slot_number])


## Пишет ли стример канала: его логин совпадает с названием канала.
func _is_streamer(login: String) -> bool:
	var channel := SessionConfig.channel.strip_edges().to_lower()
	if channel.is_empty():
		return false
	return login.strip_edges().to_lower() == channel


## Возвращает в лобби с теми же игроками и настройками; чат остаётся подключённым.
func _reset_to_lobby() -> void:
	if _resetting:
		return
	_resetting = true
	_autoplay_running = false
	_awaiting_command = false
	_pending_command = {}
	print("GAME: !reset от стримера, возврат в лобби")
	get_tree().call_deferred("change_scene_to_file", LOBBY_SCENE)


## Совпадает ли сообщение чата с текущим игроком. Основной ключ — Twitch ID,
## запасной — логин (например, если в одном из сообщений не было user-id).
func _is_current_player_message(player: PlayerData, login: String, user_id: String) -> bool:
	var uid := user_id.strip_edges()
	if not uid.is_empty() and player.twitch_id == uid:
		return true
	var login_lower := login.strip_edges().to_lower()
	if not player.twitch_login.is_empty():
		return player.twitch_login == login_lower
	return player.twitch_id == login_lower


func _on_chat_disconnected() -> void:
	if _from_lobby:
		print("GAME CHAT: соединение потеряно, ходы пойдут по таймеру")


func _on_chat_error(message: String) -> void:
	if _from_lobby:
		print("GAME CHAT ERROR: %s" % message)
