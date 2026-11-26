// Добавляет отладочных игроков в сессию канала.
// Сервер должен быть запущен с флагом --debug.
//
// Запуск: node tools/debug_join.js <канал> [количество] [ws-адрес]
// Пример: node tools/debug_join.js testchan 3

const channel = process.argv[2];
const count = Math.max(1, Math.min(8, Number(process.argv[3] || 3)));
const url = process.argv[4] || process.env.WS_URL || "ws://127.0.0.1:8080";
const names = ["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel"];

if (!channel) {
	console.error("Укажите канал: node tools/debug_join.js <канал> [количество]");
	process.exit(1);
}

const ws = new WebSocket(url);
let joined = false;

ws.addEventListener("open", () => {
	ws.send(JSON.stringify({ t: "hello", channel, max_players: 8 }));
});

ws.addEventListener("message", async (event) => {
	const raw = typeof event.data === "string" ? event.data : await event.data.text();
	if (!raw.startsWith("{")) return;
	let message;
	try {
		message = JSON.parse(raw);
	} catch {
		return;
	}
	if (message.t !== "state" || joined) return;
	joined = true;
	for (let index = 0; index < count; index += 1) {
		ws.send(JSON.stringify({
			t: "cmd",
			c: "debug_join",
			login: `debug${index + 1}`,
			display_name: names[index],
			user_id: `debug-user-${index + 1}`,
		}));
	}
	setTimeout(() => {
		console.log(`Добавлено игроков: ${count}, канал: #${channel}`);
		ws.close();
		process.exit(0);
	}, 800);
});

ws.addEventListener("error", (event) => {
	console.error("Ошибка WebSocket:", event.message || event);
	process.exit(1);
});
