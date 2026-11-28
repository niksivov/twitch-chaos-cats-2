class_name BoosterData
extends Resource

## Описание бустера. Один ресурс — один бустер в каталоге.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Путь к иконке. Текстура загружается лениво: серверу она не нужна,
## а клиент читает её только когда карточка действительно показывается.
@export var icon_path: String = ""
var _icon_cache: Texture2D = null

var icon: Texture2D:
	get:
		if _icon_cache == null and not icon_path.is_empty():
			_icon_cache = load(icon_path) as Texture2D
		return _icon_cache
@export var price: int = 0
## Сколько монет получает покупатель сразу при покупке.
@export var coins_on_purchase: int = 0
## Сколько побед получает покупатель сразу при покупке.
@export var wins_on_purchase: int = 0
## Сколько монет получает покупатель при покупке за каждый уже купленный
## им бустер (сам покупаемый бустер не считается).
@export var coins_per_owner_booster_on_purchase: int = 0
## Сколько монет получает покупатель при покупке за каждую победу игроков
## противоположной команды.
@export var coins_per_opponent_win_on_purchase: int = 0
## Сколько монет крадёт у каждого игрока, у которого есть хотя бы 1 монета.
@export var steal_coins_on_purchase: int = 0
## Если покупатель уже владеет этим бустером, при покупке им любого
## следующего бустера ему возвращается указанный процент цены покупки.
## При нескольких копиях проценты суммируются.
@export_range(0, 1000, 0.1) var cashback_percent_on_purchase: float = 0.0
## Бонус к счёту команды в процентах, если random_bonus выключен.
@export var bonus_percent: float = 0.0
## Если больше 0, бонус действует только начиная с указанного раунда.
@export var bonus_from_round: int = 0
## Если включено, бонус действует только если владелец проиграл предыдущий раунд.
@export var requires_previous_loss: bool = false
## Если включено, при каждом подсчёте очков бонус выбирается случайно
## в диапазоне bonus_min_percent..bonus_max_percent с шагом 0.1%.
@export var random_bonus: bool = false
@export_range(0, 1000, 0.1) var bonus_min_percent: float = 0.0
@export_range(0, 1000, 0.1) var bonus_max_percent: float = 0.0
## Если включено, при подсчёте очков бустер с вероятностью chance_percent
## даёт bonus_percent, иначе 0%. «Шпора» даёт bonus_percent всегда.
@export var chance_bonus: bool = false
@export_range(0, 100, 0.1) var chance_percent: float = 50.0
## Если включено, бонус начисляется за каждую победу игроков противоположной
## команды: значение разыгрывается отдельно за каждую победу и суммируется.
@export var bonus_per_opponent_win: bool = false
## Если включено, бонус начисляется за каждую победу владельца бустера:
## значение разыгрывается отдельно за каждую победу и суммируется.
@export var bonus_per_owner_win: bool = false
## Если включено, бонус начисляется за каждый бустер, купленный всеми игроками:
## значение разыгрывается отдельно за каждый бустер и суммируется.
@export var bonus_per_booster_in_game: bool = false
## Если не 0, за каждый зелёный бустер, купленный всеми игроками (бустер
## учитывается во всех своих цветах), начисляется этот процент. Может быть
## отрицательным.
@export_range(-1000, 1000, 0.1) var bonus_per_green_booster_in_game: float = 0.0
## Если не 0, за каждый фиолетовый бустер, купленный всеми игроками (бустер
## учитывается во всех своих цветах), начисляется этот процент. Может быть
## отрицательным.
@export_range(-1000, 1000, 0.1) var bonus_per_purple_booster_in_game: float = 0.0
## Если включено, бонус начисляется за каждый бустер, купленный владельцем:
## значение разыгрывается отдельно за каждый бустер и суммируется.
@export var bonus_per_owner_booster: bool = false
## Если больше 0, бонус равен этому проценту за каждый другой бустер
## владельца, дающий 0% при текущем подсчёте. Другие бустеры с таким же
## эффектом не учитываются.
@export_range(0, 1000, 0.1) var bonus_per_zero_owner_booster: float = 0.0
## Если включено, бонус начисляется за место владельца в очереди ходов:
## значение разыгрывается отдельно за каждое место и суммируется.
@export var bonus_per_turn_position: bool = false
## Если включено, бонус начисляется за номер раунда, в котором получен
## бустер: значение разыгрывается отдельно за каждый раунд и суммируется.
@export var bonus_per_purchase_round: bool = false
## Если включено, бонус начисляется за каждый сыгранный раунд, включая
## текущий: значение разыгрывается отдельно за каждый раунд и суммируется.
@export var bonus_per_played_round: bool = false
## Если включено, бонус начисляется за каждую целую минуту, прошедшую
## с начала матча до начала подсчёта очков: значение разыгрывается
## отдельно за каждую минуту и суммируется.
@export var bonus_per_match_minute: bool = false
## Если не 0, бонус начисляется за каждый бустер владельца, у которого есть
## хотя бы один из указанных цветов: значение разыгрывается отдельно за каждый
## бустер и суммируется.
@export_flags("Красный", "Зеленый", "Синий", "Желтый", "Фиолетовый") var bonus_per_owner_colors: int = 0
## Если больше 0, за каждый бустер владельца указанных цветов начисляется
## этот фиксированный процент (вместо случайного значения).
@export_range(0, 1000, 0.1) var bonus_per_owner_color_percent: float = 0.0
## Если включено, бонус начисляется за каждый уникальный цвет среди бустеров
## владельца: значение разыгрывается отдельно за каждый цвет и суммируется.
@export var bonus_per_owner_unique_colors: bool = false
## Если не 0, бонус начисляется за каждый бустер команды владельца (включая
## его собственные), у которого есть хотя бы один из указанных цветов:
## за каждый такой бустер начисляется bonus_per_team_color_percent.
@export_flags("Красный", "Зеленый", "Синий", "Желтый", "Фиолетовый") var bonus_per_team_colors: int = 0
@export_range(0, 1000, 0.1) var bonus_per_team_color_percent: float = 0.0
## Если не 0, бонус начисляется за каждый бустер союзников владельца
## (без его собственных), у которого есть хотя бы один из указанных цветов:
## за каждый такой бустер начисляется bonus_per_ally_color_percent.
@export_flags("Красный", "Зеленый", "Синий", "Желтый", "Фиолетовый") var bonus_per_ally_colors: int = 0
@export_range(0, 1000, 0.1) var bonus_per_ally_color_percent: float = 0.0
## Если включено, бонус начисляется за каждую монету владельца:
## значение разыгрывается отдельно за каждую монету и суммируется.
@export var bonus_per_owner_coin: bool = false
## Если включено, бонус начисляется за каждую монету союзников владельца
## (без его собственных монет): значение разыгрывается отдельно за каждую
## монету и суммируется.
@export var bonus_per_team_coin: bool = false
## Если включено, бонус начисляется за каждую монету всех игроков команды
## противников: значение разыгрывается отдельно за каждую монету и суммируется.
@export var bonus_per_opponent_coin: bool = false
## Если не 0, бонус действует только если у владельца есть минимум
## required_owner_colors_min бустеров с любым из указанных цветов.
@export_flags("Красный", "Зеленый", "Синий", "Желтый", "Фиолетовый") var required_owner_colors: int = 0
@export var required_owner_colors_min: int = 0
## Если больше 0, бонус действует только если у владельца не больше
## required_owner_colors_max бустеров с любым из указанных цветов.
@export var required_owner_colors_max: int = 0
## Если не 0, у владельца должен быть хотя бы один бустер каждого
## из указанных цветов.
@export_flags("Красный", "Зеленый", "Синий", "Желтый", "Фиолетовый") var required_owner_colors_all: int = 0
## Если не пуст, бонус действует только если у владельца есть все указанные бустеры.
@export var required_owner_booster_ids: Array[String] = []
## Если не пуст, бонус действует только если все указанные бустеры есть
## у команды владельца (учитываются бустеры владельца и союзников; пустые
## слоты не считаются).
@export var required_team_booster_ids: Array[String] = []
## Если больше 0, бонус действует только если суммарное число побед всех
## игроков команды владельца больше указанного значения.
@export var requires_team_wins_over: int = 0
## Если больше 0, бонус действует только если у владельца меньше указанного
## числа побед.
@export var requires_owner_wins_under: int = 0
## Если включено, бонус действует только если у команды владельца больше
## суммарных монет, чем у команды противников.
@export var requires_team_coins_lead: bool = false
## Если включено, бонус зависит от команды владельца бустера.
@export var team_dependent_bonus: bool = false
@export_range(0, 1000, 0.1) var bonus_team1_percent: float = 0.0
@export_range(0, 1000, 0.1) var bonus_team2_percent: float = 0.0
## Если включено, все остальные красные бустеры владельца дают максимальный эффект.
@export var maximizes_red_bonus: bool = false
## Цвета бустера — можно выбрать сразу несколько.
@export_flags("Красный", "Зеленый", "Синий", "Желтый", "Фиолетовый") var colors: int = 0
## За сколько зеленых бустеров считается этот бустер при подсчёте очков
## (для бустеров без зеленого цвета значение не учитывается).
@export_range(1, 9, 1) var green_booster_units: int = 1
## Если включено, при подсчёте все остальные бустеры владельца считаются
## ещё и зелеными.
@export var makes_owner_boosters_green: bool = false
## Если включено, при подсчёте все остальные бустеры владельца считаются
## ещё и фиолетовыми.
@export var makes_owner_boosters_purple: bool = false
## При покупке копия бустера возвращается в пул.
@export var returns_copy_to_pool: bool = false
## Если больше 0, этот процент делится поровну между всеми копиями бустера
## у всех игроков (с точностью до 0.01%); остальные бонусные поля игнорируются.
@export_range(0, 1000, 0.01) var distributed_bonus_percent: float = 0.0
## При покупке бустер становится копией бустера, который владелец купил
## в прошлом раунде. В первом раунде (или если покупки не было) остаётся собой.
@export var copies_previous_purchase: bool = false
## При покупке бустер становится копией последнего купленного в игре бустера
## (у любого игрока). Если покупок ещё не было, остаётся собой.
@export var copies_last_purchase: bool = false
## При покупке остаётся собой до следующей покупки владельца, затем
## превращается в копию купленного бустера со всеми его эффектами.
@export var copies_next_purchase: bool = false
## При покупке забирает случайный бустер у игрока противоположной команды:
## становится его копией, а у противника слот остаётся пустым до конца игры.
@export var steals_opponent_booster: bool = false
## При получении игрок до конца игры перестаёт участвовать в очереди ходов,
## но остаётся в игре и продолжает приносить очки команде.
@export var excludes_owner_from_turns: bool = false
## При покупке заполняет все пустые слоты владельца (до 9) копиями случайных
## бустеров из пула, магазина и других игроков; сам бустер слот не занимает.
@export var fills_empty_slots_on_purchase: bool = false
## Если больше 0, при покупке бустер становится копией случайного бустера
## указанной цены: копии берутся из пула, магазина и слотов всех игроков,
## включая самого покупателя. Если подходящих бустеров нет, бустер остаётся собой.
@export_range(0, 1000, 1) var copies_random_booster_of_price: int = 0
## При покупке заменяет уже купленные бустеры владельца: все бустеры ценой 2
## становятся случайными бустерами ценой 4, а ценой 4 — случайными бустерами
## ценой 6. Старые бустеры удаляются из игры, новые берутся копиями из каталога
## и срабатывают как купленные. Заменяются бустеры, бывшие у владельца до покупки.
@export var upgrades_owned_boosters_by_price: bool = false


## Красный ли бустер (первый бит маски цветов).
func is_red_booster() -> bool:
	return (colors & 1) != 0


## Сколько зеленых бустеров дает этот бустер в цветовых эффектах подсчёта.
## У «Четырехлистника» — 4, у остальных зеленых бустеров — 1.
func green_units() -> int:
	if (colors & 2) == 0:
		return 0
	return maxi(1, green_booster_units)


## Сколько зеленых бустеров дает этот бустер при подсчёте, если у владельца
## есть «Кисть»: незеленый бустер тоже считается зеленым.
func green_units_with_brush(owner_has_brush: bool) -> int:
	var units := green_units()
	if units == 0 and owner_has_brush:
		return 1
	return units


## Сколько фиолетовых бустеров дает этот бустер при подсчёте, если у владельца
## есть «Валик»: нефиолетовый бустер тоже считается фиолетовым. Несколько
## «Валиков» не суммируются, каждый бустер учитывается не больше одного раза.
func purple_units_with_roller(owner_has_roller: bool) -> int:
	if (colors & 16) != 0:
		return 1
	return 1 if owner_has_roller else 0


## Бонус для текущего подсчёта очков. Случайный диапазон разыгрывается
## заново каждый раунд с точностью до 0.1%.
func roll_bonus_percent(maximize: bool = false) -> float:
	if not random_bonus:
		return float(bonus_percent)
	var min_value := minf(bonus_min_percent, bonus_max_percent)
	var max_value := maxf(bonus_min_percent, bonus_max_percent)
	if maximize:
		return max_value
	var steps := maxi(0, roundi((max_value - min_value) * 10.0))
	return min_value + float(randi_range(0, steps)) / 10.0


## Итоговый бонус с учётом команды владельца, побед противоположной команды
## и владельца, суммарных побед команды владельца, личных побед владельца, монетного
## преимущества команды владельца, количества купленных бустеров (всех
## игроков или только владельца), их цветов (личных, уникальных, всей команды и союзников),
## места владельца в очереди, раунда получения бустера, числа сыгранных раундов,
## времени матча, монет владельца, союзников и противников, конкретных
## бустеров (личных и командных), текущего раунда, проигрыша в прошлом раунде
## и максимального эффекта от «Шпоры».
func calculate_bonus_percent(opponent_wins: int = 0, team: int = 0, maximize: bool = false, total_boosters: int = 0, owner_boosters: int = 0, current_round: int = 0, owner_booster_colors: Array = [], lost_previous_round: bool = false, owner_coins: int = 0, owner_booster_ids: Array = [], owner_team_wins: int = 0, owner_wins: int = 0, team_coins_lead: bool = false, owner_team_coins: int = 0, opponent_team_coins: int = 0, owner_turn_number: int = 0, booster_purchase_round: int = 0, match_minutes: int = 0, team_booster_colors: Array = [], ally_booster_colors: Array = [], green_boosters_in_game: int = 0, purple_boosters_in_game: int = 0, team_booster_ids: Array = []) -> float:
	if bonus_from_round > 0 and current_round < bonus_from_round:
		return 0.0
	if requires_previous_loss and not lost_previous_round:
		return 0.0
	if requires_team_wins_over > 0 and owner_team_wins <= requires_team_wins_over:
		return 0.0
	if requires_owner_wins_under > 0 and owner_wins >= requires_owner_wins_under:
		return 0.0
	if requires_team_coins_lead and not team_coins_lead:
		return 0.0
	if not required_owner_booster_ids.is_empty():
		for required_id in required_owner_booster_ids:
			if not owner_booster_ids.has(required_id):
				return 0.0
	if not required_team_booster_ids.is_empty():
		for required_id in required_team_booster_ids:
			if not team_booster_ids.has(required_id):
				return 0.0
	if required_owner_colors != 0:
		var required_count := 0
		for color_mask in owner_booster_colors:
			if (int(color_mask) & required_owner_colors) != 0:
				required_count += 1
		if required_count < required_owner_colors_min:
			return 0.0
		if required_owner_colors_max > 0 and required_count > required_owner_colors_max:
			return 0.0
	if required_owner_colors_all != 0:
		var covered_colors := 0
		for color_mask in owner_booster_colors:
			covered_colors |= int(color_mask)
		if (covered_colors & required_owner_colors_all) != required_owner_colors_all:
			return 0.0
	if chance_bonus:
		if maximize or randf() * 100.0 < chance_percent:
			return bonus_percent
		return 0.0
	if team_dependent_bonus:
		if maximize:
			return maxf(bonus_team1_percent, bonus_team2_percent)
		if team == 1:
			return bonus_team1_percent
		if team == 2:
			return bonus_team2_percent
		return 0.0
	if bonus_per_booster_in_game:
		if maximize:
			return roundf(roll_bonus_percent(true) * maxi(0, total_boosters) * 10.0) / 10.0
		var booster_total := 0.0
		for index in maxi(0, total_boosters):
			booster_total += roll_bonus_percent()
		return roundf(booster_total * 10.0) / 10.0
	if bonus_per_green_booster_in_game != 0.0 or bonus_per_purple_booster_in_game != 0.0:
		var green_total := float(bonus_percent)
		green_total += bonus_per_green_booster_in_game * maxi(0, green_boosters_in_game)
		green_total += bonus_per_purple_booster_in_game * maxi(0, purple_boosters_in_game)
		return roundf(green_total * 10.0) / 10.0
	if bonus_per_owner_booster:
		if maximize:
			return roundf(roll_bonus_percent(true) * maxi(0, owner_boosters) * 10.0) / 10.0
		var owner_total := 0.0
		for index in maxi(0, owner_boosters):
			owner_total += roll_bonus_percent()
		return roundf(owner_total * 10.0) / 10.0
	if bonus_per_turn_position:
		var turns := maxi(0, owner_turn_number)
		if maximize:
			return roundf(roll_bonus_percent(true) * turns * 10.0) / 10.0
		var turn_total := 0.0
		for index in turns:
			turn_total += roll_bonus_percent()
		return roundf(turn_total * 10.0) / 10.0
	if bonus_per_purchase_round:
		var rounds := maxi(0, booster_purchase_round)
		if maximize:
			return roundf(roll_bonus_percent(true) * rounds * 10.0) / 10.0
		var round_total := 0.0
		for index in rounds:
			round_total += roll_bonus_percent()
		return roundf(round_total * 10.0) / 10.0
	if bonus_per_played_round:
		var played_rounds := maxi(0, current_round)
		if maximize:
			return roundf(roll_bonus_percent(true) * played_rounds * 10.0) / 10.0
		var played_total := 0.0
		for index in played_rounds:
			played_total += roll_bonus_percent()
		return roundf(played_total * 10.0) / 10.0
	if bonus_per_match_minute:
		var minutes := maxi(0, match_minutes)
		if maximize:
			return roundf(roll_bonus_percent(true) * minutes * 10.0) / 10.0
		var minute_total := 0.0
		for index in minutes:
			minute_total += roll_bonus_percent()
		return roundf(minute_total * 10.0) / 10.0
	if bonus_per_owner_unique_colors:
		var unique_colors := 0
		for color_mask in owner_booster_colors:
			unique_colors |= int(color_mask)
		var unique_count := 0
		for color_index in 5:
			if (unique_colors & (1 << color_index)) != 0:
				unique_count += 1
		if maximize:
			return roundf(roll_bonus_percent(true) * unique_count * 10.0) / 10.0
		var unique_total := 0.0
		for index in unique_count:
			unique_total += roll_bonus_percent()
		return roundf(unique_total * 10.0) / 10.0
	if bonus_per_owner_colors != 0:
		var matching := 0
		for color_mask in owner_booster_colors:
			if (int(color_mask) & bonus_per_owner_colors) != 0:
				matching += 1
		if bonus_per_owner_color_percent > 0.0:
			return roundf(bonus_per_owner_color_percent * matching * 10.0) / 10.0
		if maximize:
			return roundf(roll_bonus_percent(true) * matching * 10.0) / 10.0
		var color_total := 0.0
		for index in matching:
			color_total += roll_bonus_percent()
		return roundf(color_total * 10.0) / 10.0
	if bonus_per_team_colors != 0 and bonus_per_team_color_percent != 0.0:
		var team_matching := 0
		for color_mask in team_booster_colors:
			if (int(color_mask) & bonus_per_team_colors) != 0:
				team_matching += 1
		return roundf(bonus_per_team_color_percent * team_matching * 10.0) / 10.0
	if bonus_per_ally_colors != 0 and bonus_per_ally_color_percent != 0.0:
		var ally_matching := 0
		for color_mask in ally_booster_colors:
			if (int(color_mask) & bonus_per_ally_colors) != 0:
				ally_matching += 1
		return roundf(bonus_per_ally_color_percent * ally_matching * 10.0) / 10.0
	if bonus_per_owner_coin:
		if maximize:
			return roundf(roll_bonus_percent(true) * maxi(0, owner_coins) * 10.0) / 10.0
		var coin_total := 0.0
		for index in maxi(0, owner_coins):
			coin_total += roll_bonus_percent()
		return roundf(coin_total * 10.0) / 10.0
	if bonus_per_team_coin:
		var ally_coins := maxi(0, owner_team_coins - owner_coins)
		if maximize:
			return roll_bonus_percent(true) * ally_coins
		var team_coin_total := 0.0
		for index in ally_coins:
			team_coin_total += roll_bonus_percent()
		return snappedf(team_coin_total, 0.0001)
	if bonus_per_opponent_coin:
		if maximize:
			return roll_bonus_percent(true) * maxi(0, opponent_team_coins)
		var opponent_coin_total := 0.0
		for index in maxi(0, opponent_team_coins):
			opponent_coin_total += roll_bonus_percent()
		return snappedf(opponent_coin_total, 0.0001)
	if bonus_per_owner_win:
		var wins := maxi(0, owner_wins)
		if maximize:
			return roundf(roll_bonus_percent(true) * wins * 10.0) / 10.0
		var win_total := 0.0
		for index in wins:
			win_total += roll_bonus_percent()
		return roundf(win_total * 10.0) / 10.0
	if not bonus_per_opponent_win:
		return roll_bonus_percent(maximize)
	if maximize:
		return roundf(roll_bonus_percent(true) * maxi(0, opponent_wins) * 10.0) / 10.0
	var total := 0.0
	for index in maxi(0, opponent_wins):
		total += roll_bonus_percent()
	return roundf(total * 10.0) / 10.0
