class_name SessionConfig
extends RefCounted

## Настройки текущей сессии: канал, лимит игроков, длительность хода,
## размер магазина и список участников, набранных в лобби через чат.

static var channel: String = ""
static var max_players: int = 8
static var turn_seconds: int = 60
static var shop_size: int = 8
static var players: Array[PlayerData] = []
