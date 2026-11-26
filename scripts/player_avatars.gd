class_name PlayerAvatars
extends RefCounted

## Аватары игроков, которые выдаются по порядку подключения к лобби.
## Индекс 0 — первый подключившийся, 7 — восьмой.

const AVATARS := [
	preload("res://assets/avatars/avatar_1_streamer.png"),
	preload("res://assets/avatars/avatar_2_surfer.png"),
	preload("res://assets/avatars/avatar_3_chef.png"),
	preload("res://assets/avatars/avatar_4_dj.png"),
	preload("res://assets/avatars/avatar_5_barista.png"),
	preload("res://assets/avatars/avatar_6_perfumer.png"),
	preload("res://assets/avatars/avatar_7_cinema.png"),
	preload("res://assets/avatars/avatar_8_magician.png"),
]


## Возвращает аватар по порядковому номеру подключения (0–7)
## или null, если номер вне диапазона.
static func get_avatar(index: int) -> Texture2D:
	if index < 0 or index >= AVATARS.size():
		return null
	return AVATARS[index] as Texture2D
