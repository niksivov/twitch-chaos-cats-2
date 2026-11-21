class_name RoundResultsPopup
extends Control

## Поп-ап итогов раунда: сверху победители, ниже проигравшие.
## Показывается на 5 секунд, затем плавно исчезает.

signal display_finished

const HOLD_TIME := 5.0
const FADE_IN_TIME := 0.2
const FADE_OUT_TIME := 0.3
const CARD_SCENE := preload("res://scenes/round_result_card.tscn")

@onready var _winners_section: VBoxContainer = $Card/Content/Results/WinnersSection
@onready var _winners_row: HBoxContainer = $Card/Content/Results/WinnersSection/Row
@onready var _losers_section: VBoxContainer = $Card/Content/Results/LosersSection
@onready var _losers_row: HBoxContainer = $Card/Content/Results/LosersSection/Row

var _tween: Tween


## Показывает итоги раунда: список победителей и проигравших
## и изменения побед/монет по каждому игроку.
func show_results(winners: Array[PlayerData], losers: Array[PlayerData], changes: Dictionary) -> void:
	var ordered_winners := _sort_by_turn(winners)
	var ordered_losers := _sort_by_turn(losers)
	_fill_row(_winners_row, ordered_winners, changes)
	_fill_row(_losers_row, ordered_losers, changes)
	_winners_section.visible = not ordered_winners.is_empty()
	_losers_section.visible = not ordered_losers.is_empty()
	_play()


## Немедленно скрыть поп-ап и остановить анимацию.
func hide_popup() -> void:
	var was_visible := visible
	_stop_animation()
	modulate.a = 1.0
	hide()
	if was_visible:
		display_finished.emit()


func _sort_by_turn(players: Array[PlayerData]) -> Array[PlayerData]:
	var ordered: Array[PlayerData] = []
	ordered.assign(players)
	ordered.sort_custom(_compare_by_turn)
	return ordered


func _compare_by_turn(a: PlayerData, b: PlayerData) -> bool:
	# Исключённые из очереди (turn_number == 0) идут в конце.
	var a_turn := a.turn_number if a.turn_number > 0 else 99
	var b_turn := b.turn_number if b.turn_number > 0 else 99
	if a_turn != b_turn:
		return a_turn < b_turn
	return a.nickname < b.nickname


func _fill_row(row: HBoxContainer, players: Array[PlayerData], changes: Dictionary) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for player in players:
		var change: Dictionary = changes.get(player, {})
		var card := CARD_SCENE.instantiate() as RoundResultCard
		row.add_child(card)
		card.setup(
			player,
			int(change.get("wins_before", player.wins)),
			int(change.get("wins_after", player.wins)),
			int(change.get("coins_before", player.coins)),
			int(change.get("coins_after", player.coins)),
		)


func _play() -> void:
	_stop_animation()
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_TIME)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_TIME)
	_tween.tween_callback(_finish_display)


func _finish_display() -> void:
	hide()
	display_finished.emit()


func _stop_animation() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
