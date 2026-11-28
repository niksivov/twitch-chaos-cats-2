// Локальный сервер Web-клиента: отдаёт build/web и проксирует /ws
// на игровой сервер Godot (по умолчанию 127.0.0.1:8080).
//
// Запуск: node tools/serve_web.js
// Переменные: PORT (8090), WS_PORT (8080), WS_HOST (127.0.0.1),
// WEB_ROOT (build/web).

const http = require("http");
const fs = require("fs");
const net = require("net");
const path = require("path");

const ROOT = path.resolve(
	process.env.WEB_ROOT || path.join(__dirname, "..", "build", "web")
);
const PORT = Number(process.env.PORT || 8090);
const WS_PORT = Number(process.env.WS_PORT || 8080);
const WS_HOST = process.env.WS_HOST || "127.0.0.1";

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
	".webmanifest": "application/manifest+json",
	".txt": "text/plain; charset=utf-8",
};

function fileHeaders(stat, filePath) {
	return {
		"Content-Type": MIME[path.extname(filePath).toLowerCase()] || "application/octet-stream",
		"Cache-Control": "no-cache",
		"ETag": `"${stat.size.toString(16)}-${Math.floor(stat.mtimeMs).toString(16)}"`,
		"Last-Modified": stat.mtime.toUTCString(),
		"X-Content-Type-Options": "nosniff",
	};
}

function isFresh(req, headers) {
	const ifNoneMatch = req.headers["if-none-match"];
	if (ifNoneMatch && ifNoneMatch.split(",").some((tag) => tag.trim() === headers.ETag)) {
		return true;
	}
	const ifModifiedSince = req.headers["if-modified-since"];
	if (ifModifiedSince) {
		const since = Date.parse(ifModifiedSince);
		const modified = Date.parse(headers["Last-Modified"]);
		if (!Number.isNaN(since) && !Number.isNaN(modified) && modified <= since) {
			return true;
		}
	}
	return false;
}

function sendFile(req, res, filePath) {
	fs.stat(filePath, (err, stat) => {
		if (err || !stat.isFile()) {
			res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
			res.end("Not found");
			return;
		}
		const headers = fileHeaders(stat, filePath);
		if (isFresh(req, headers)) {
			res.writeHead(304, headers);
			res.end();
			return;
		}
		headers["Content-Length"] = stat.size;
		res.writeHead(200, headers);
		if (req.method === "HEAD") {
			res.end();
			return;
		}
		const stream = fs.createReadStream(filePath);
		stream.on("error", () => res.destroy());
		stream.pipe(res);
	});
}

function sendHealth(req, res) {
	res.writeHead(200, {
		"Content-Type": "application/json; charset=utf-8",
		"Cache-Control": "no-store",
	});
	if (req.method === "HEAD") {
		res.end();
		return;
	}
	res.end(JSON.stringify({ ok: true, ws: `${WS_HOST}:${WS_PORT}` }));
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
	if (pathname === "/healthz") {
		sendHealth(req, res);
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
	const upstream = net.connect(WS_PORT, WS_HOST);
	const close = () => {
		socket.destroy();
		upstream.destroy();
	};
	upstream.setTimeout(10000, close);
	upstream.on("error", close);
	socket.on("error", close);
	upstream.on("connect", () => {
		upstream.setTimeout(0);
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
	console.log(`WEB: http://0.0.0.0:${PORT} (статика ${ROOT})`);
	console.log(`WS: /ws -> ws://${WS_HOST}:${WS_PORT}`);
});
