class_name MatchState
extends RefCounted

## Состояние матча: пул бустеров, магазин, раунды, команды, очередь ходов,
## покупки, подсчёт очков и конец игры.

enum Phase {
	PURCHASE,
	SCORING,
	GAME_OVER,
}

const START_SCORE := 1000000
const START_COINS := 8
const MAX_ROUNDS := 9
const WIN_TARGET := 5
const MAX_SHOP_SIZE := 8

var players: Array[PlayerData] = []
var pool: Array[BoosterData] = []
var shop: Array[BoosterData] = []
var catalog: Dictionary = {}
var shop_size: int = 8
var round_number: int = 0
var turn_order: Array[PlayerData] = []
var turn_index: int = 0
var phase: int = Phase.PURCHASE
var round_resolved: bool = false
var team_scores: Dictionary = {1: START_SCORE, 2: START_SCORE}
var previous_losers: Array[PlayerData] = []
var winners: Array[PlayerData] = []
var losers: Array[PlayerData] = []
var is_draw: bool = false
var game_winner: PlayerData = null
## Последний купленный в матче бустер: игрок и индекс в его списке.
var last_purchase_player: PlayerData = null
var last_purchase_index: int = -1
## id последнего купленного в игре бустера, даже если он не занял слот.
var last_purchase_id: String = ""
## Время начала матча в миллисекундах и число целых минут, зафиксированное
## на начало текущего подсчёта очков.
var match_start_msec: int = 0
var scoring_match_minutes: int = 0


## Подготавливает матч: сбрасывает игроков и собирает пул бустеров.
func setup(new_players: Array[PlayerData], all_boosters: Array[BoosterData], new_shop_size: int = 8) -> void:
	players.assign(new_players)
	pool.clear()
	for booster in all_boosters:
		pool.append(booster)
	shop_size = clampi(new_shop_size, 1, MAX_SHOP_SIZE)
	catalog.clear()
	for booster in all_boosters:
		if booster == null or booster.id.is_empty():
			continue
		catalog[booster.id] = booster
	round_number = 0
	turn_index = 0
	phase = Phase.PURCHASE
	round_resolved = false
	game_winner = null
	last_purchase_player = null
	last_purchase_index = -1
	last_purchase_id = ""
	previous_losers.clear()
	winners.clear()
	losers.clear()
	is_draw = false
	team_scores = {1: START_SCORE, 2: START_SCORE}
	match_start_msec = Time.get_ticks_msec()
	scoring_match_minutes = 0
	# У каждого игрока свой цвет ника: палитра из 8 цветов без повторов.
	for index in players.size():
		var player := players[index]
		player.nick_color = PlayerData.NICK_COLORS[index % PlayerData.NICK_COLORS.size()]
		player.coins = START_COINS
		player.boosters.clear()
		player.booster_rounds.clear()
		player.round_history.clear()
		player.round_purchases.clear()
		player.team = 0
		player.turn_number = 0
		player.turn_excluded = false
		player.bonus_wins = 0


## Начинает новый раунд: команды, очередь хода и магазин.
func start_round() -> void:
	if phase == Phase.GAME_OVER or game_winner != null:
		return
	round_number += 1
	if round_number > MAX_ROUNDS:
		game_winner = _choose_winner_by_wins(players)
		phase = Phase.GAME_OVER
		return
	_assign_teams()
	_build_turn_order()
	_form_shop()
	turn_index = 0
	# Если ходить некому, раунд сразу переходит к подсчёту очков.
	phase = Phase.PURCHASE if not turn_order.is_empty() else Phase.SCORING
	round_resolved = false
	team_scores = {1: START_SCORE, 2: START_SCORE}
	winners.clear()
	losers.clear()
	is_draw = false


func get_current_player() -> PlayerData:
	if phase != Phase.PURCHASE:
		return null
	if turn_index < 0 or turn_index >= turn_order.size():
		return null
	return turn_order[turn_index]


func get_team_players(team: int) -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	for player in players:
		if player.team == team:
			result.append(player)
	return result


## Игроки команды в порядке их хода в текущем раунде: по turn_order,
## затем исключённые из очереди (turn_number == 0) в конце.
func get_team_players_in_turn_order(team: int) -> Array[PlayerData]:
	if turn_order.is_empty():
		return get_team_players(team)
	var result: Array[PlayerData] = []
	for player in turn_order:
		if player.team == team:
			result.append(player)
	for player in players:
		if player.team == team and player.turn_number == 0:
			result.append(player)
	return result


## Индекс последнего купленного бустера указанного игрока или -1.
func get_last_purchase_index(player: PlayerData) -> int:
	if player == null or player != last_purchase_player:
		return -1
	if last_purchase_index < 0 or last_purchase_index >= player.boosters.size():
		return -1
	if player.boosters[last_purchase_index].is_empty():
		return -1
	return last_purchase_index


## id последнего купленного в игре бустера (с учётом копирования) или "".
func get_last_purchase_booster_id() -> String:
	return last_purchase_id


## Суммарное число побед игроков команды, противоположной указанному игроку.
func _count_opponent_wins(player: PlayerData) -> int:
	var team := player.team
	if team != 1 and team != 2:
		return 0
	var opponent_team := 2 if team == 1 else 1
	var total := 0
	for other in players:
		if other.team == opponent_team:
			total += other.wins
	return total


## Есть ли у игрока бустер, который делает все его остальные бустеры зелеными.
func _has_greening_booster(player: PlayerData) -> bool:
	for booster_id in player.boosters:
		if booster_id.is_empty():
			continue
		var data: BoosterData = catalog.get(booster_id)
		if data != null and data.makes_owner_boosters_green:
			return true
	return false


## Есть ли у игрока бустер, который делает все его остальные бустеры фиолетовыми.
func _has_purpling_booster(player: PlayerData) -> bool:
	for booster_id in player.boosters:
		if booster_id.is_empty():
			continue
		var data: BoosterData = catalog.get(booster_id)
		if data != null and data.makes_owner_boosters_purple:
			return true
	return false


## Добавляет цвета бустера в список для цветовых эффектов. Если у владельца
## есть «Кисть», незеленый бустер дополнительно считается зеленым; если есть
## «Валик», нефиолетовый бустер дополнительно считается фиолетовым.
func _append_booster_colors(target: Array[int], booster: BoosterData, owner_has_brush: bool, owner_has_roller: bool) -> void:
	target.append(booster.colors)
	var green_units := booster.green_units_with_brush(owner_has_brush)
	# Одна зеленая запись уже есть в colors, если бустер зеленый.
	var already_green := 1 if (booster.colors & 2) != 0 else 0
	for extra in green_units - already_green:
		target.append(2)
	if (booster.colors & 16) == 0 and owner_has_roller:
		target.append(16)


## Можно ли текущему игроку купить бустер из указанного слота магазина.
func can_buy_slot(slot_index: int) -> bool:
	if phase != Phase.PURCHASE:
		return false
	if slot_index < 0 or slot_index >= shop.size():
		return false
	var booster: BoosterData = shop[slot_index]
	if booster == null:
		return false
	var player := get_current_player()
	if player == null:
		return false
	if booster.price > player.coins:
		return false
	if booster.fills_empty_slots_on_purchase:
		return _count_owned_boosters(player) < PlayerData.MAX_BOOSTERS
	return player.has_free_booster_slot()


## Номер случайного доступного по цене бустера или -1.
func find_random_affordable_slot() -> int:
	var candidates: Array[int] = []
	for index in shop.size():
		if can_buy_slot(index):
			candidates.append(index)
	if candidates.is_empty():
		return -1
	return int(candidates.pick_random())


## Номер первого доступного по цене бустера или -1.
func find_first_affordable_slot() -> int:
	for index in shop.size():
		if can_buy_slot(index):
			return index
	return -1


## Покупка бустера текущим игроком. Возвращает false, если ход невозможен.
func buy_from_slot(slot_index: int) -> bool:
	if not can_buy_slot(slot_index):
		return false
	var booster: BoosterData = shop[slot_index]
	var player := get_current_player()
	# «Ртуть» может превратиться в копию покупки прошлого раунда, тогда
	# срабатывают эффекты именно этой копии (например, монеты за «Слиток»).
	var acquired := _resolve_purchased_booster(player, booster)
	# «Штамп-карта» не занимает слот: она только заполняет пустые.
	var occupies_slot := not booster.fills_empty_slots_on_purchase
	var owned_boosters_before := _count_owned_boosters(player)
	# Кэшбэк «Свиньи-копилки»: процент берётся по бустерам, которые уже были
	# у покупателя до этой покупки (сам покупаемый бустер не считается).
	var cashback_percent := _get_cashback_percent(player)
	# «Пластилины», купленные раньше: эта покупка превратит их в свои копии.
	var pending_plasticines := _collect_next_purchase_indexes(player)
	var acquired_index := -1
	if occupies_slot:
		if not player.add_booster(acquired.id, round_number):
			return false
		acquired_index = player.boosters.size() - 1
	last_purchase_player = player
	last_purchase_index = acquired_index
	last_purchase_id = acquired.id
	player.coins -= booster.price
	if cashback_percent > 0.0:
		player.coins += roundi(float(booster.price) * cashback_percent / 100.0)
	_apply_purchase_effects(player, acquired, owned_boosters_before, acquired_index)
	# «Ключ» забирает случайный бустер у противника и становится его копией.
	if acquired.steals_opponent_booster:
		var stolen := _steal_random_opponent_booster(player)
		if stolen != null:
			acquired = stolen
			last_purchase_id = stolen.id
			if acquired_index >= 0:
				player.boosters[acquired_index] = stolen.id
				player.set_booster_round(acquired_index, round_number)
			_apply_purchase_effects(player, stolen, owned_boosters_before, acquired_index)
	shop[slot_index] = null
	if acquired.returns_copy_to_pool:
		pool.append(acquired)
	player.set_round_purchase(round_number, acquired.id)
	for index in pending_plasticines:
		player.boosters[index] = acquired.id
		player.set_booster_round(index, round_number)
		_apply_purchase_effects(player, acquired, _count_owned_boosters(player), index)
	# «Корона» и её копии могут сразу принести победный порог: игра
	# заканчивается немедленно, без подсчёта очков и ходов остальных игроков.
	if not _check_win_target():
		_advance_turn()
	return true


## Забирает случайный бустер у игрока противоположной команды. Слот
## противника остаётся пустым до конца игры. Возвращает украденный бустер
## или null, если у противников нет бустеров.
func _steal_random_opponent_booster(player: PlayerData) -> BoosterData:
	if player.team != 1 and player.team != 2:
		return null
	var opponent_team := 2 if player.team == 1 else 1
	var candidates: Array[Dictionary] = []
	for other in players:
		if other.team != opponent_team:
			continue
		for index in other.boosters.size():
			var booster_id := other.boosters[index]
			if booster_id.is_empty():
				continue
			var data: BoosterData = catalog.get(booster_id)
			if data != null:
				candidates.append({"player": other, "index": index, "booster": data})
	if candidates.is_empty():
		return null
	var chosen: Dictionary = candidates[randi() % candidates.size()]
	var victim: PlayerData = chosen["player"]
	var victim_index: int = chosen["index"]
	var stolen: BoosterData = chosen["booster"]
	victim.boosters[victim_index] = ""
	victim.set_booster_round(victim_index, 0)
	return stolen


## Число реально купленных бустеров: пустые слоты не считаются.
func _count_owned_boosters(player: PlayerData) -> int:
	var total := 0
	for booster_id in player.boosters:
		if not booster_id.is_empty():
			total += 1
	return total


## Суммарный процент кэшбэка по всем имеющимся у игрока копиям.
func _get_cashback_percent(player: PlayerData) -> float:
	var percent := 0.0
	for booster_id in player.boosters:
		if booster_id.is_empty():
			continue
		var data: BoosterData = catalog.get(booster_id)
		if data != null:
			percent += data.cashback_percent_on_purchase
	return percent


## Применяет эффекты бустера, срабатывающие при покупке.
func _apply_purchase_effects(player: PlayerData, booster: BoosterData, owned_boosters_before: int, source_index: int = -1, allow_upgrade: bool = true) -> void:
	player.coins += booster.coins_on_purchase
	player.bonus_wins += booster.wins_on_purchase
	player.coins += booster.coins_per_owner_booster_on_purchase * owned_boosters_before
	if booster.coins_per_opponent_win_on_purchase > 0:
		player.coins += booster.coins_per_opponent_win_on_purchase * _count_opponent_wins(player)
	if booster.steal_coins_on_purchase > 0:
		for other in players:
			if other.coins >= 1:
				var stolen := mini(booster.steal_coins_on_purchase, other.coins)
				other.coins -= stolen
				player.coins += stolen
	if booster.excludes_owner_from_turns:
		player.turn_excluded = true
	if booster.fills_empty_slots_on_purchase:
		_fill_empty_booster_slots(player)
	if booster.upgrades_owned_boosters_by_price and allow_upgrade:
		_upgrade_owned_boosters(player, source_index)


## «Волшебная палочка»: все бустеры владельца ценой 2 и 4, бывшие у него
## до покупки, заменяются на случайные копии из каталога ценой на 2 больше.
## Старые бустеры удаляются из игры и в пул не возвращаются.
func _upgrade_owned_boosters(player: PlayerData, source_index: int) -> void:
	var upgrades: Array[Dictionary] = []
	for index in player.boosters.size():
		if index == source_index:
			continue
		var booster_id := player.boosters[index]
		if booster_id.is_empty():
			continue
		var data: BoosterData = catalog.get(booster_id)
		if data == null or (data.price != 2 and data.price != 4):
			continue
		upgrades.append({"index": index, "price": data.price})
	for upgrade in upgrades:
		var index: int = upgrade["index"]
		var price: int = upgrade["price"]
		var chosen := _random_catalog_booster_by_price(price + 2)
		if chosen == null:
			continue
		player.boosters[index] = chosen.id
		player.set_booster_round(index, round_number)
		_apply_transformed_booster(player, index, chosen)
		if _check_win_target():
			return


## Случайный бустер из каталога указанной цены (копия, источник остаётся на месте).
func _random_catalog_booster_by_price(price: int) -> BoosterData:
	var candidates: Array[BoosterData] = []
	for value in catalog.values():
		var data := value as BoosterData
		if data != null and data.price == price:
			candidates.append(data)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


## Заменяет слот на полученный бустер и применяет его эффекты «при покупке».
## Копирующие и крадущие бустеры раскрываются один раз, как при обычной покупке.
func _apply_transformed_booster(player: PlayerData, index: int, booster: BoosterData) -> void:
	var acquired := _resolve_purchased_booster(player, booster)
	if acquired.steals_opponent_booster:
		var stolen := _steal_random_opponent_booster(player)
		if stolen != null:
			acquired = _resolve_purchased_booster(player, stolen)
	var owned_before := maxi(0, _count_owned_boosters(player) - 1)
	if acquired.fills_empty_slots_on_purchase:
		player.boosters[index] = ""
		player.set_booster_round(index, 0)
	else:
		player.boosters[index] = acquired.id
		player.set_booster_round(index, round_number)
	_apply_purchase_effects(player, acquired, owned_before, index, false)
	if acquired.returns_copy_to_pool:
		pool.append(acquired)


## Заполняет все пустые слоты игрока (до 9) копиями случайных бустеров
## из пула, магазина и других игроков. Купленная карта слот не занимает.
func _fill_empty_booster_slots(player: PlayerData) -> void:
	var candidates := _collect_fill_candidates(player)
	if candidates.is_empty():
		return
	var chosen: BoosterData
	for index in player.boosters.size():
		if not player.boosters[index].is_empty():
			continue
		chosen = candidates[randi() % candidates.size()]
		player.boosters[index] = chosen.id
		player.set_booster_round(index, round_number)
	while player.boosters.size() < PlayerData.MAX_BOOSTERS:
		chosen = candidates[randi() % candidates.size()]
		player.boosters.append(chosen.id)
		player.booster_rounds.append(round_number)


## Бустеры, которые могут попасть в пустые слоты: копии из пула, магазина
## и слотов других игроков. Сами заполняющие карты не выбираются.
func _collect_fill_candidates(player: PlayerData) -> Array[BoosterData]:
	var candidates: Array[BoosterData] = []
	for booster in pool:
		_add_fill_candidate(candidates, booster)
	for booster in shop:
		_add_fill_candidate(candidates, booster)
	for other in players:
		if other == player:
			continue
		for booster_id in other.boosters:
			var data: BoosterData = catalog.get(booster_id)
			_add_fill_candidate(candidates, data)
	return candidates


func _add_fill_candidate(candidates: Array[BoosterData], booster: BoosterData) -> void:
	if booster == null or booster.id.is_empty():
		return
	if booster.fills_empty_slots_on_purchase:
		return
	candidates.append(booster)


## Индексы «Пластилинов», которые ждут следующую покупку владельца.
func _collect_next_purchase_indexes(player: PlayerData) -> Array[int]:
	var result: Array[int] = []
	for index in player.boosters.size():
		var data: BoosterData = catalog.get(player.boosters[index])
		if data != null and data.copies_next_purchase:
			result.append(index)
	return result


## Возвращает бустер, который фактически получает игрок: «Ртуть» — копию
## покупки владельца в прошлом раунде, «Мел» — копию последнего купленного
## в игре бустера любого игрока, «Маска» — копию случайного бустера ценой 6.
func _resolve_purchased_booster(player: PlayerData, booster: BoosterData) -> BoosterData:
	if booster.copies_last_purchase:
		var last_id := get_last_purchase_booster_id()
		if last_id.is_empty():
			return booster
		var last: BoosterData = catalog.get(last_id)
		return last if last != null else booster
	if booster.copies_previous_purchase:
		var previous_id := player.get_round_purchase(round_number - 1)
		if previous_id.is_empty():
			return booster
		var previous: BoosterData = catalog.get(previous_id)
		return previous if previous != null else booster
	if booster.copies_random_booster_of_price > 0:
		var candidates := _collect_booster_copies_by_price(booster.copies_random_booster_of_price)
		if candidates.is_empty():
			return booster
		return candidates[randi() % candidates.size()]
	return booster


## Копии бустеров указанной цены из пула, магазина и слотов всех игроков,
## включая самого покупателя.
func _collect_booster_copies_by_price(price: int) -> Array[BoosterData]:
	var candidates: Array[BoosterData] = []
	for booster in pool:
		if booster != null and booster.price == price:
			candidates.append(booster)
	for booster in shop:
		if booster != null and booster.price == price:
			candidates.append(booster)
	for other in players:
		for booster_id in other.boosters:
			if booster_id.is_empty():
				continue
			var data: BoosterData = catalog.get(booster_id)
			if data != null and data.price == price:
				candidates.append(data)
	return candidates


func skip_turn() -> bool:
	if phase != Phase.PURCHASE:
		return false
	_advance_turn()
	return true


func is_game_over() -> bool:
	return phase == Phase.GAME_OVER


## Сколько целых минут прошло с начала матча.
func get_elapsed_full_minutes() -> int:
	if match_start_msec == 0:
		return 0
	return maxi(0, (Time.get_ticks_msec() - match_start_msec) / 60000)


## Завершает раунд: возвращает некупленные бустеры, считает очки, награды
## и историю, проверяет конец игры.
func finish_round() -> Dictionary:
	if phase != Phase.SCORING:
		return {}
	# Время матча фиксируется один раз на начало подсчёта и одинаково
	# для обеих команд.
	scoring_match_minutes = get_elapsed_full_minutes()
	for booster in shop:
		if booster != null:
			pool.append(booster)
	shop.clear()

	var team_wins := {1: 0, 2: 0}
	var team_coins := {1: 0, 2: 0}
	var total_boosters := 0
	# Число зелёных и фиолетовых бустеров, купленных всеми игроками
	# (бустер учитывается во всех своих цветах; «Кисть» добавляет зелёный,
	# «Валик» — фиолетовый всем остальным бустерам своего владельца).
	var green_boosters_in_game := 0
	var purple_boosters_in_game := 0
	for player in players:
		total_boosters += _count_owned_boosters(player)
		var owner_has_brush := _has_greening_booster(player)
		var owner_has_roller := _has_purpling_booster(player)
		for booster_id in player.boosters:
			if booster_id.is_empty():
				continue
			var owned: BoosterData = catalog.get(booster_id)
			if owned == null:
				continue
			green_boosters_in_game += owned.green_units_with_brush(owner_has_brush)
			purple_boosters_in_game += owned.purple_units_with_roller(owner_has_roller)
		if player.team == 1 or player.team == 2:
			team_wins[player.team] += player.wins
			team_coins[player.team] += player.coins

	# Сколько копий каждого «распределяемого» бустера есть у всех игроков.
	var distributed_copies := {}
	for player in players:
		for booster_id in player.boosters:
			if booster_id.is_empty():
				continue
			var data: BoosterData = catalog.get(booster_id)
			if data != null and data.distributed_bonus_percent > 0.0:
				distributed_copies[booster_id] = int(distributed_copies.get(booster_id, 0)) + 1

	var multipliers := {1: 1.0, 2: 1.0}
	var bonuses_by_player := {}
	var player_multipliers := {}
	var team_counts := {1: 0, 2: 0}
	for player in players:
		var team := player.team
		if team != 1 and team != 2:
			continue
		team_counts[team] += 1
		var opponent_team := 2 if team == 1 else 1
		var opponent_wins: int = team_wins[opponent_team]
		var owned_ids: Array[String] = []
		for booster_id in player.boosters:
			if not booster_id.is_empty():
				owned_ids.append(booster_id)
		var owner_boosters := owned_ids.size()
		var owner_booster_colors: Array[int] = []
		var maximize_red := false
		var owner_has_brush := _has_greening_booster(player)
		var owner_has_roller := _has_purpling_booster(player)
		for booster_id in owned_ids:
			var booster: BoosterData = catalog.get(booster_id)
			if booster == null:
				continue
			_append_booster_colors(owner_booster_colors, booster, owner_has_brush, owner_has_roller)
			if booster.maximizes_red_bonus:
				maximize_red = true
		# Цвета бустеров всей команды, включая собственные бустеры владельца,
		# отдельно цвета бустеров только союзников и id всех бустеров команды.
		var team_booster_colors: Array[int] = []
		var ally_booster_colors: Array[int] = []
		var team_booster_ids: Array[String] = []
		for mate in players:
			if mate.team != team:
				continue
			var mate_has_brush := _has_greening_booster(mate)
			var mate_has_roller := _has_purpling_booster(mate)
			for booster_id in mate.boosters:
				if booster_id.is_empty():
					continue
				var mate_booster: BoosterData = catalog.get(booster_id)
				if mate_booster == null:
					continue
				team_booster_ids.append(booster_id)
				_append_booster_colors(team_booster_colors, mate_booster, mate_has_brush, mate_has_roller)
				if mate != player:
					_append_booster_colors(ally_booster_colors, mate_booster, mate_has_brush, mate_has_roller)
		var booster_bonuses: Array[float] = []
		booster_bonuses.resize(player.boosters.size())
		booster_bonuses.fill(0.0)
		var player_multiplier := 1.0
		# Сначала считаем все бустеры, кроме «Трости»: её бонус зависит от того,
		# сколько других бустеров владельца дают 0%.
		for booster_index in player.boosters.size():
			var booster_id := player.boosters[booster_index]
			if booster_id.is_empty():
				continue
			var data: BoosterData = catalog.get(booster_id)
			if data == null:
				push_warning("Unknown booster id: %s" % booster_id)
				continue
			if data.bonus_per_zero_owner_booster > 0.0:
				continue
			var bonus := 0.0
			if data.distributed_bonus_percent > 0.0:
				var copies := int(distributed_copies.get(booster_id, 0))
				if copies > 0:
					bonus = snappedf(data.distributed_bonus_percent / float(copies), 0.01)
			else:
				var maximize := maximize_red and data.is_red_booster()
				bonus = data.calculate_bonus_percent(opponent_wins, team, maximize, total_boosters, owner_boosters, round_number, owner_booster_colors, previous_losers.has(player), player.coins, owned_ids, team_wins[team], player.wins, team_coins[team] > team_coins[opponent_team], team_coins[team], team_coins[opponent_team], player.turn_number, player.get_booster_round(booster_index), scoring_match_minutes, team_booster_colors, ally_booster_colors, green_boosters_in_game, purple_boosters_in_game, team_booster_ids)
			booster_bonuses[booster_index] = bonus
			var factor := 1.0 + bonus / 100.0
			multipliers[team] *= factor
			player_multiplier *= factor
		# «Трость» даёт фиксированный процент за каждый другой бустер
		# владельца, который при подсчёте остался с нулевым бонусом.
		var zero_boosters := 0
		for booster_index in player.boosters.size():
			if player.boosters[booster_index].is_empty():
				continue
			var zero_data: BoosterData = catalog.get(player.boosters[booster_index])
			if zero_data == null or zero_data.bonus_per_zero_owner_booster > 0.0:
				continue
			if is_zero_approx(booster_bonuses[booster_index]):
				zero_boosters += 1
		for booster_index in player.boosters.size():
			var booster_id := player.boosters[booster_index]
			if booster_id.is_empty():
				continue
			var data: BoosterData = catalog.get(booster_id)
			if data == null or data.bonus_per_zero_owner_booster <= 0.0:
				continue
			var bonus := roundf(data.bonus_per_zero_owner_booster * zero_boosters * 10.0) / 10.0
			booster_bonuses[booster_index] = bonus
			var factor := 1.0 + bonus / 100.0
			multipliers[team] *= factor
			player_multiplier *= factor
		bonuses_by_player[player] = booster_bonuses
		player_multipliers[player] = player_multiplier

	# Если команды неравны, команда в меньшинстве получает компенсацию:
	# её счёт умножается на средний итоговый множитель её игроков
	# (среднее арифметическое бонусов, округлённое до 0.1%).
	var correction_team := 0
	var correction_percent := 0.0
	var correction_multiplier := 1.0
	if team_counts[1] != team_counts[2]:
		correction_team = 1 if team_counts[1] < team_counts[2] else 2
		var total_multiplier := 0.0
		var count := 0
		for player in players:
			if player.team != correction_team:
				continue
			total_multiplier += float(player_multipliers.get(player, 1.0))
			count += 1
		if count > 0:
			var average_multiplier := total_multiplier / float(count)
			correction_percent = roundf((average_multiplier - 1.0) * 100.0 * 10.0) / 10.0
			correction_multiplier = 1.0 + correction_percent / 100.0
			multipliers[correction_team] *= correction_multiplier

	team_scores = {
		1: roundi(START_SCORE * multipliers[1]),
		2: roundi(START_SCORE * multipliers[2]),
	}
	is_draw = team_scores[1] == team_scores[2]
	winners.clear()
	losers.clear()
	var winning_team := 0
	if team_scores[1] > team_scores[2]:
		winning_team = 1
	elif team_scores[2] > team_scores[1]:
		winning_team = 2

	# Значения до наград нужны поп-апу итогов раунда для стрелок «было → стало».
	var player_changes := {}
	for player in players:
		player_changes[player] = {
			"wins_before": player.wins,
			"coins_before": player.coins,
		}

	for player in players:
		var player_won := is_draw or player.team == winning_team
		var result := PlayerData.RoundResult.WIN if player_won else PlayerData.RoundResult.LOSS
		player.set_round_result(round_number, result)
		if player_won:
			winners.append(player)
		else:
			losers.append(player)

	for player in winners:
		player.coins += 3
	for player in losers:
		player.coins += 5

	for player in players:
		var change: Dictionary = player_changes[player]
		change["wins_after"] = player.wins
		change["coins_after"] = player.coins

	previous_losers.clear()
	previous_losers.assign(losers)
	round_resolved = true

	if not _check_win_target() and round_number >= MAX_ROUNDS:
		game_winner = _choose_winner_by_wins(players)
		phase = Phase.GAME_OVER

	return {
		"team1_score": team_scores[1],
		"team2_score": team_scores[2],
		"draw": is_draw,
		"winners": winners,
		"losers": losers,
		"player_changes": player_changes,
		"booster_bonuses": bonuses_by_player,
		"correction_team": correction_team,
		"correction_percent": correction_percent,
		"correction_multiplier": correction_multiplier,
		"game_over": phase == Phase.GAME_OVER,
		"game_winner": game_winner,
	}


func _advance_turn() -> void:
	turn_index += 1
	if turn_index >= turn_order.size():
		turn_index = turn_order.size()
		phase = Phase.SCORING


## Делит игроков на две команды случайным образом, но максимально поровну:
## при чётном числе — равные составы, при нечётном — лишний игрок достаётся
## случайной команде (например, 5 игроков делятся как 3 против 2 или 2 против 3).
## Вызывается заново в начале каждого раунда, поэтому составы каждый раунд новые.
func _assign_teams() -> void:
	var shuffled: Array[PlayerData] = []
	shuffled.assign(players)
	shuffled.shuffle()
	var team1_count: int = players.size() / 2
	if players.size() % 2 == 1 and randi() % 2 == 0:
		team1_count += 1
	for index in shuffled.size():
		shuffled[index].team = 1 if index < team1_count else 2


func _build_turn_order() -> void:
	turn_order.clear()
	for player in players:
		if player.turn_excluded:
			player.turn_number = 0
			continue
		turn_order.append(player)
	# В первом раунде монеты и победы у всех одинаковые, а прошлого раунда
	# ещё нет, поэтому очередь полностью случайная.
	if round_number == 1:
		turn_order.shuffle()
		for index in turn_order.size():
			turn_order[index].turn_number = index + 1
		return
	# Случайный ключ для игроков с равными монетами, победами и прошлым результатом.
	var random_keys := {}
	for player in turn_order:
		random_keys[player] = randf()
	turn_order.sort_custom(func(a: PlayerData, b: PlayerData) -> bool:
		return _compare_turn_order(a, b, random_keys)
	)
	for index in turn_order.size():
		turn_order[index].turn_number = index + 1


func _compare_turn_order(a: PlayerData, b: PlayerData, random_keys: Dictionary) -> bool:
	if a.coins != b.coins:
		return a.coins > b.coins
	if a.wins != b.wins:
		return a.wins < b.wins
	var a_lost := previous_losers.has(a)
	var b_lost := previous_losers.has(b)
	if a_lost != b_lost:
		return a_lost
	return random_keys[a] < random_keys[b]


func _form_shop() -> void:
	shop.clear()
	var candidates: Array[BoosterData] = []
	candidates.assign(pool)
	candidates.shuffle()

	var used_ids := {}
	var selected: Array[BoosterData] = []
	for booster in candidates:
		if booster == null or booster.id.is_empty():
			continue
		if used_ids.has(booster.id):
			continue
		used_ids[booster.id] = true
		selected.append(booster)
		if selected.size() >= shop_size:
			break

	for booster in selected:
		pool.erase(booster)

	# В магазине не больше shop_size бустеров; если в пуле не хватает
	# уникальных бустеров, магазин заполняется меньшим числом.
	shop.assign(selected)


## Проверяет победный порог у всех игроков (с учётом бонусных побед
## от «Короны»). Если кто-то достиг порога, выбирает победителя и сразу
## завершает игру. Возвращает true, если игра окончена.
func _check_win_target() -> bool:
	var reached: Array[PlayerData] = []
	for player in players:
		if player.wins >= WIN_TARGET:
			reached.append(player)
	if reached.is_empty():
		return false
	game_winner = _choose_winner_by_coins(reached)
	phase = Phase.GAME_OVER
	return true


func _choose_winner_by_wins(candidates: Array[PlayerData]) -> PlayerData:
	if candidates.is_empty():
		return null
	var max_wins := -1
	for player in candidates:
		max_wins = max(max_wins, player.wins)
	var top: Array[PlayerData] = []
	for player in candidates:
		if player.wins == max_wins:
			top.append(player)
	return _choose_winner_by_coins(top)


func _choose_winner_by_coins(candidates: Array[PlayerData]) -> PlayerData:
	if candidates.is_empty():
		return null
	var max_coins := -1
	for player in candidates:
		max_coins = max(max_coins, player.coins)
	var top: Array[PlayerData] = []
	for player in candidates:
		if player.coins == max_coins:
			top.append(player)
	return top[randi() % top.size()]
