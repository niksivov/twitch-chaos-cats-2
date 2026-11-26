// Отправляет сообщение в сессию от имени отладочного игрока.
// Сервер должен быть запущен с флагом --debug.
//
// Запуск: node tools/debug_say.js <канал> <логин> <текст> [user_id] [ws-адрес]
// Пример: node tools/debug_say.js testchan debug1 "!0"

const channel = process.argv[2];
const login = process.argv[3];
const text = process.argv[4];
const number = (login || "").replace(/[^0-9]/g, "") || "1";
const userId = process.argv[5] || process.env.DEBUG_USER_ID || `debug-user-${number}`;
const url = process.argv[6] || process.env.WS_URL || "ws://127.0.0.1:8080";

if (!channel || !login || text === undefined) {
	console.error("Запуск: node tools/debug_say.js <канал> <логин> <текст> [user_id] [ws-адрес]");
	process.exit(1);
}

const ws = new WebSocket(url);
let sent = false;

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
	if (message.t !== "state" || sent) return;
	sent = true;
	ws.send(JSON.stringify({
		t: "cmd",
		c: "debug_say",
		login,
		display_name: login,
		user_id: userId,
		text,
	}));
	setTimeout(() => {
		console.log(`Отправлено ${login}: ${text}`);
		ws.close();
		process.exit(0);
	}, 300);
});

ws.addEventListener("error", (event) => {
	console.error("Ошибка WebSocket:", event.message || event);
	process.exit(1);
});
