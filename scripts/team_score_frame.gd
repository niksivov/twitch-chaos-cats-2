class_name TeamScoreFrame
extends Control

## Счёт команды в нижней зоне. В начале раунда равен 1 000 000.

const START_SCORE := 1000000

@export var score: int = START_SCORE:
	set(value):
		score = value
		if is_node_ready():
			_label.text = _format_score(score)

@onready var _label: Label = $Score


func _ready() -> void:
	_label.text = _format_score(score)


func _format_score(value: int) -> String:
	var digits := str(value)
	var grouped := ""
	while digits.length() > 3:
		grouped = " " + digits.substr(digits.length() - 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return digits + grouped
