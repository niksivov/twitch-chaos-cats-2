class_name NetProtocol
extends RefCounted

## Общие функции сетевого режима: имена каналов, каталог бустеров и цвета ников.

const CHANNEL_PATTERN := "^[a-z0-9_]{4,25}$"
const BOOSTERS_DIR := "res://resources/boosters"


## Приводит ввод к имени канала: убирает @, #, адрес twitch.tv и лишние пробелы.
static func normalize_channel(raw: String) -> String:
	var value := raw.strip_edges().to_lower()
	value = value.trim_prefix("https://").trim_prefix("http://")
	value = value.trim_prefix("www.")
	value = value.trim_prefix("twitch.tv/")
	value = value.trim_prefix("@").trim_prefix("#")
	value = value.get_slice("?", 0).get_slice("/", 0)
	return value


static func is_valid_channel(channel: String) -> bool:
	var regex := RegEx.new()
	if regex.compile(CHANNEL_PATTERN) != OK:
		return false
	return regex.search(channel) != null


## Загружает все ресурсы бустеров, отсортированные по id.
static func load_all_boosters() -> Array[BoosterData]:
	var result: Array[BoosterData] = []
	var dir := DirAccess.open(BOOSTERS_DIR)
	if dir == null:
		push_error("Не найдена папка бустеров: %s" % BOOSTERS_DIR)
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			# В экспортированной сборке ресурсы лежат как .tres.remap,
			# а в редакторе — как .tres. Поддерживаем оба варианта.
			var clean_name := file_name.trim_suffix(".remap")
			if clean_name.ends_with(".tres"):
				var resource := load(BOOSTERS_DIR + "/" + clean_name) as BoosterData
				if resource == null:
					push_warning("Не BoosterData: %s" % clean_name)
				else:
					result.append(resource)
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a: BoosterData, b: BoosterData) -> bool: return a.id < b.id)
	return result


## Загружает один бустер по id (имя файла совпадает с id).
static func load_booster(id: String) -> BoosterData:
	if id.is_empty():
		return null
	return load(BOOSTERS_DIR + "/" + id + ".tres") as BoosterData


static func color_to_hex(color: Color) -> String:
	return color.to_html(false)


static func color_from_hex(hex: String) -> Color:
	if hex.is_empty():
		return Color.WHITE
	return Color.from_string(hex, Color.WHITE)
