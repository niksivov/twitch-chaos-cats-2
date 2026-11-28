class_name PlayerAvatars
extends RefCounted

## Аватары игроков, которые выдаются по порядку подключения к лобби.
## Индекс 0 — первый подключившийся, 7 — восьмой.

const AVATAR_PATHS := [
	"res://assets/avatars/avatar_1_streamer.png",
	"res://assets/avatars/avatar_2_surfer.png",
	"res://assets/avatars/avatar_3_chef.png",
	"res://assets/avatars/avatar_4_dj.png",
	"res://assets/avatars/avatar_5_barista.png",
	"res://assets/avatars/avatar_6_perfumer.png",
	"res://assets/avatars/avatar_7_cinema.png",
	"res://assets/avatars/avatar_8_magician.png",
]


## Возвращает аватар по порядковому номеру подключения (0–7)
## или null, если номер вне диапазона. Текстура загружается при первом
## обращении, поэтому ненужные аватары не занимают память.
static func get_avatar(index: int) -> Texture2D:
	if index < 0 or index >= AVATAR_PATHS.size():
		return null
	return load(AVATAR_PATHS[index]) as Texture2D
