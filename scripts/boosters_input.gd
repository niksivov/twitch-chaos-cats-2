extends LineEdit

## Поле количества бустеров в магазине: только цифры и диапазон 1–8.


func _ready() -> void:
	text_changed.connect(_on_text_changed)
	focus_exited.connect(_on_focus_exited)


func _on_text_changed(new_text: String) -> void:
	var filtered := ""
	for ch in new_text:
		if ch >= "1" and ch <= "8":
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
	text = str(clampi(int(text), 1, 8))
