extends LineEdit

## Поле таймера хода: только цифры и диапазон 5–600.


func _ready() -> void:
	text_changed.connect(_on_text_changed)
	focus_exited.connect(_on_focus_exited)


func _on_text_changed(new_text: String) -> void:
	var filtered := ""
	for ch in new_text:
		if ch >= "0" and ch <= "9":
			filtered += ch
	if filtered.length() > 3:
		filtered = filtered.substr(0, 3)
	if filtered != new_text:
		var caret := caret_column
		text = filtered
		caret_column = mini(caret, text.length())


func _on_focus_exited() -> void:
	if text.is_empty():
		return
	text = str(clampi(int(text), 5, 600))
