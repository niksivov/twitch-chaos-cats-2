class_name PlayerData
extends Resource

## Данные игрока. Команда и номер хода пересчитываются каждый раунд,
## купленные бустеры хранятся как идентификаторы (до 9 штук),
## результаты раундов — история побед и поражений (до 9 раундов).

const MAX_BOOSTERS := 9
const MAX_ROUNDS := 9

## Восемь уникальных цветов ников: красный, оранжевый, жёлтый, зелёный,
## бирюзовый, синий, фиолетовый, розовый.
const NICK_COLORS := [
	Color(1.0, 0.30, 0.30),
	Color(1.0, 0.62, 0.11),
	Color(1.0, 0.90, 0.43),
	Color(0.48, 0.90, 0.51),
	Color(0.18, 0.90, 0.84),
	Color(0.36, 0.65, 1.0),
	Color(0.71, 0.49, 1.0),
	Color(1.0, 0.48, 0.85),
]

enum RoundResult {
	NONE = 0,
	WIN = 1,
	LOSS = 2,
}

@export var twitch_id: String = ""
## Логин Twitch в нижнем регистре — запасной ключ для команд чата.
@export var twitch_login: String = ""
@export var nickname: String = ""
## Уникальный цвет ника; задаётся при старте матча.
@export var nick_color: Color = Color.WHITE
@export var avatar: Texture2D
## Номер аватара, выданного при подключении (1–8; 0 — без аватара).
@export_range(0, 8, 1) var avatar_index: int = 0
## 0 — команда ещё не назначена, 1 или 2 — номер команды.
@export_range(0, 2, 1) var team: int = 0
@export var coins: int = 8
## Результаты по раундам: индекс 0 — раунд 1, NONE — раунд ещё не сыгран.
@export var round_history: Array[int] = []
## Идентификаторы бустеров, максимум 9. Пустая строка — слот, из которого
## бустер забрали: он остаётся пустым до конца игры и не заполняется заново.
@export var boosters: Array[String] = []
## Раунды получения бустеров: параллельный boosters массив (0 — неизвестно).
@export var booster_rounds: Array[int] = []
## Покупки по раундам: индекс 0 — раунд 1, пустая строка — покупки не было.
@export var round_purchases: Array[String] = []
## 0 — ход ещё не назначен, 1–8 — порядковый номер хода.
@export_range(0, 8, 1) var turn_number: int = 0
## Если включено, игрок до конца игры не участвует в очереди ходов
## (эффект «Черной Метки»), но остаётся в игре и приносит очки команде.
@export var turn_excluded: bool = false
## Дополнительные победы, полученные не за раунд (например, от «Короны»).
@export var bonus_wins: int = 0


## Количество побед считается по истории и бонусным победам, отдельно не хранится.
var wins: int:
	get:
		return count_round_results(RoundResult.WIN) + bonus_wins


## Количество поражений считается по истории, отдельно не хранится.
var losses: int:
	get:
		return count_round_results(RoundResult.LOSS)


## Назначает игроку команду и номер хода на новый раунд.
func assign_round(team_number: int, turn: int) -> void:
	team = team_number
	turn_number = turn


## Записывает результат раунда (1–9). Возвращает false, если раунд или
## результат вне допустимых значений.
func set_round_result(round_number: int, result: int) -> bool:
	if round_number < 1 or round_number > MAX_ROUNDS:
		return false
	if result < RoundResult.NONE or result > RoundResult.LOSS:
		return false
	while round_history.size() < round_number:
		round_history.append(RoundResult.NONE)
	round_history[round_number - 1] = result
	return true


func record_win(round_number: int) -> bool:
	return set_round_result(round_number, RoundResult.WIN)


func record_loss(round_number: int) -> bool:
	return set_round_result(round_number, RoundResult.LOSS)


## Результат раунда (1–9); для несыгранного раунда — NONE.
func get_round_result(round_number: int) -> int:
	if round_number < 1 or round_number > round_history.size():
		return RoundResult.NONE
	return round_history[round_number - 1]


func count_round_results(result: int) -> int:
	var total := 0
	for value in round_history:
		if value == result:
			total += 1
	return total


## Записывает покупку раунда (1–9). Возвращает false, если раунд вне диапазона.
func set_round_purchase(round_number: int, booster_id: String) -> bool:
	if round_number < 1 or round_number > MAX_ROUNDS:
		return false
	while round_purchases.size() < round_number:
		round_purchases.append("")
	round_purchases[round_number - 1] = booster_id
	return true


## Бустер, купленный в раунде (1–9); пустая строка, если покупки не было.
func get_round_purchase(round_number: int) -> String:
	if round_number < 1 or round_number > round_purchases.size():
		return ""
	return round_purchases[round_number - 1]


## Добавляет бустер, если у игрока ещё есть свободная ячейка.
func add_booster(booster_id: String, round_number: int = 0) -> bool:
	if booster_id.is_empty() or boosters.size() >= MAX_BOOSTERS:
		return false
	boosters.append(booster_id)
	booster_rounds.append(round_number)
	return true


## Раунд получения бустера по индексу; 0, если данных нет.
func get_booster_round(index: int) -> int:
	if index < 0 or index >= booster_rounds.size():
		return 0
	return booster_rounds[index]


## Записывает раунд получения бустера по индексу.
func set_booster_round(index: int, round_number: int) -> void:
	if index < 0:
		return
	while booster_rounds.size() <= index:
		booster_rounds.append(0)
	booster_rounds[index] = round_number


func has_free_booster_slot() -> bool:
	return boosters.size() < MAX_BOOSTERS
