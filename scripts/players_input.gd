extends LineEdit

## Поле максимального количества игроков: только цифры и диапазон 3–8.


func _ready() -> void:
	text_changed.connect(_on_text_changed)
	focus_exited.connect(_on_focus_exited)


func _on_text_changed(new_text: String) -> void:
	var filtered := ""
	for ch in new_text:
		if ch >= "3" and ch <= "8":
			filtered += ch
	if filtered.length() > 1:
		filtered = filtered.substr(0, 1)
	if filtered != new_text:
		var caret := caret_column
		text = filtered
		caret_column = mini(caret, text.length())


func _on_focus_exited() -> void:
	if text.is_empty():
		text = "8"
		return
	text = str(clampi(int(text), 3, 8))
