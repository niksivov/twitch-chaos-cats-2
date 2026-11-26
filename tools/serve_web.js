// Локальный сервер для Web-клиента: отдаёт build/web и проксирует /ws
// на игровой сервер Godot (по умолчанию 127.0.0.1:8080).
//
// Запуск: node tools/serve_web.js
// Порт страницы: PORT (по умолчанию 8090), порт сервера: WS_PORT (8080).
// Открыть: http://127.0.0.1:8090

const http = require("http");
const fs = require("fs");
const net = require("net");
const path = require("path");

const ROOT = path.resolve(__dirname, "..", "build", "web");
const PORT = Number(process.env.PORT || 8090);
const WS_PORT = Number(process.env.WS_PORT || 8080);

const MIME = {
	".html": "text/html; charset=utf-8",
	".js": "text/javascript; charset=utf-8",
	".wasm": "application/wasm",
	".pck": "application/octet-stream",
	".png": "image/png",
	".svg": "image/svg+xml",
	".ico": "image/x-icon",
	".json": "application/json; charset=utf-8",
	".css": "text/css; charset=utf-8",
};

function sendFile(req, res, filePath) {
	fs.stat(filePath, (err, stat) => {
		if (err || !stat.isFile()) {
			res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
			res.end("Not found");
			return;
		}
		res.writeHead(200, {
			"Content-Type": MIME[path.extname(filePath).toLowerCase()] || "application/octet-stream",
			"Content-Length": stat.size,
			"Cache-Control": "no-store",
		});
		if (req.method === "HEAD") {
			res.end();
			return;
		}
		fs.createReadStream(filePath).pipe(res);
	});
}

const server = http.createServer((req, res) => {
	let pathname;
	try {
		pathname = decodeURIComponent(new URL(req.url, "http://localhost").pathname);
	} catch {
		res.writeHead(400, { "Content-Type": "text/plain; charset=utf-8" });
		res.end("Bad request");
		return;
	}
	if (pathname === "/") {
		pathname = "/index.html";
	}
	const filePath = path.resolve(ROOT, "." + pathname);
	if (filePath !== ROOT && !filePath.startsWith(ROOT + path.sep)) {
		res.writeHead(403, { "Content-Type": "text/plain; charset=utf-8" });
		res.end("Forbidden");
		return;
	}
	sendFile(req, res, filePath);
});

// Прокси WebSocket: сохраняем исходный HTTP-запрос (включая /ws) и
// перекладываем байты между браузером и сервером Godot.
server.on("upgrade", (req, socket, head) => {
	const upstream = net.connect(WS_PORT, "127.0.0.1");
	const close = () => {
		socket.destroy();
		upstream.destroy();
	};
	upstream.on("error", close);
	socket.on("error", close);
	upstream.on("connect", () => {
		upstream.setNoDelay(true);
		socket.setNoDelay(true);
		const lines = [`${req.method} ${req.url} HTTP/${req.httpVersion}`];
		for (let i = 0; i < req.rawHeaders.length; i += 2) {
			lines.push(`${req.rawHeaders[i]}: ${req.rawHeaders[i + 1]}`);
		}
		upstream.write(lines.join("\r\n") + "\r\n\r\n");
		if (head && head.length > 0) {
			upstream.write(head);
		}
		socket.pipe(upstream);
		upstream.pipe(socket);
	});
});

server.listen(PORT, "0.0.0.0", () => {
	console.log(`WEB: http://127.0.0.1:${PORT} (статика ${ROOT})`);
	console.log(`WS: /ws -> ws://127.0.0.1:${WS_PORT}`);
});
