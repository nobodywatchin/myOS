import fs from "node:fs";
import http from "node:http";
import net from "node:net";
import path from "node:path";

const assetRoot = process.env.OPENCLAW_UI_ROOT || "/app/dist/control-ui";
const listenHost = process.env.OPENCLAW_UI_HOST || "0.0.0.0";
const listenPort = Number.parseInt(process.env.OPENCLAW_UI_PORT || "18080", 10);
const gatewayHost = process.env.OPENCLAW_GATEWAY_HOST || "127.0.0.1";
const gatewayPort = Number.parseInt(process.env.OPENCLAW_GATEWAY_PORT || "18789", 10);
const basePath = normalizeBasePath(process.env.OPENCLAW_CONTROL_UI_BASE_PATH || "");
const assistantName = process.env.OPENCLAW_UI_ASSISTANT_NAME || "OpenClaw";
const assistantAgentId = process.env.OPENCLAW_UI_ASSISTANT_AGENT_ID || "main";
const serverVersion = process.env.OPENCLAW_UI_SERVER_VERSION || "myos-tenant-ui";

const staticAssetExtensions = new Set([
  ".css",
  ".gif",
  ".ico",
  ".jpeg",
  ".jpg",
  ".js",
  ".json",
  ".map",
  ".png",
  ".svg",
  ".txt",
  ".webp",
]);

const proxiedPrefixes = [
  "/__openclaw/",
  "/api",
  "/avatar",
  "/health",
  "/healthz",
  "/plugins",
  "/ready",
  "/readyz",
];

function normalizeBasePath(rawValue) {
  const trimmed = rawValue.trim();
  if (!trimmed || trimmed === "/") {
    return "";
  }

  let normalized = trimmed.startsWith("/") ? trimmed : `/${trimmed}`;
  if (normalized.length > 1 && normalized.endsWith("/")) {
    normalized = normalized.slice(0, -1);
  }

  return normalized;
}

function stripBasePath(pathname) {
  if (!basePath) {
    return pathname;
  }

  if (pathname === basePath) {
    return "/";
  }

  if (pathname.startsWith(`${basePath}/`)) {
    return pathname.slice(basePath.length) || "/";
  }

  return null;
}

function isReadMethod(method) {
  return method === "GET" || method === "HEAD";
}

function shouldProxyHttp(pathname) {
  const relativePath = stripBasePath(pathname);
  if (relativePath === null) {
    return false;
  }

  return proxiedPrefixes.some((prefix) => relativePath === prefix || relativePath.startsWith(`${prefix}/`));
}

function shouldProxyUpgrade(pathname) {
  return stripBasePath(pathname) !== null;
}

function toSafeRelativePath(pathname) {
  const relativePath = stripBasePath(pathname);
  if (relativePath === null) {
    return null;
  }

  const normalized = path.posix.normalize(relativePath);
  if (normalized.includes("\0") || normalized.startsWith("../") || normalized === "..") {
    return null;
  }

  return normalized === "/" ? "" : normalized.replace(/^\/+/, "");
}

function contentTypeFor(filePath) {
  switch (path.extname(filePath).toLowerCase()) {
    case ".css":
      return "text/css; charset=utf-8";
    case ".gif":
      return "image/gif";
    case ".html":
      return "text/html; charset=utf-8";
    case ".ico":
      return "image/x-icon";
    case ".jpeg":
    case ".jpg":
      return "image/jpeg";
    case ".js":
      return "application/javascript; charset=utf-8";
    case ".json":
    case ".map":
      return "application/json; charset=utf-8";
    case ".png":
      return "image/png";
    case ".svg":
      return "image/svg+xml";
    case ".txt":
      return "text/plain; charset=utf-8";
    case ".webp":
      return "image/webp";
    default:
      return "application/octet-stream";
  }
}

function sendJson(res, statusCode, body) {
  const payload = Buffer.from(JSON.stringify(body));
  res.writeHead(statusCode, {
    "Cache-Control": "no-cache",
    "Content-Length": String(payload.length),
    "Content-Type": "application/json; charset=utf-8",
  });
  res.end(payload);
}

function sendPlainText(res, statusCode, message) {
  res.writeHead(statusCode, {
    "Cache-Control": "no-cache",
    "Content-Type": "text/plain; charset=utf-8",
  });
  res.end(message);
}

function serveFile(req, res, filePath) {
  let stats;

  try {
    stats = fs.statSync(filePath);
  } catch {
    return false;
  }

  if (!stats.isFile()) {
    return false;
  }

  res.writeHead(200, {
    "Cache-Control": filePath.endsWith("index.html") ? "no-cache" : "public, max-age=300",
    "Content-Length": String(stats.size),
    "Content-Type": contentTypeFor(filePath),
  });

  if (req.method === "HEAD") {
    res.end();
    return true;
  }

  fs.createReadStream(filePath).pipe(res);
  return true;
}

function serveStatic(req, res, pathname) {
  if (!isReadMethod(req.method)) {
    sendPlainText(res, 405, "Method Not Allowed");
    return;
  }

  const relativePath = toSafeRelativePath(pathname);
  if (relativePath === null) {
    sendPlainText(res, 404, "Not Found");
    return;
  }

  const localConfigPath = stripBasePath(pathname);
  if (localConfigPath === "/__openclaw/control-ui-config.json") {
    sendJson(res, 200, {
      assistantAgentId,
      assistantAvatar: null,
      assistantName,
      basePath,
      serverVersion,
    });
    return;
  }

  const candidatePath = path.resolve(assetRoot, relativePath || "index.html");
  const assetPath = candidatePath.startsWith(path.resolve(assetRoot)) ? candidatePath : null;

  if (assetPath && serveFile(req, res, assetPath)) {
    return;
  }

  if (assetPath && staticAssetExtensions.has(path.extname(assetPath).toLowerCase())) {
    sendPlainText(res, 404, "Not Found");
    return;
  }

  const indexPath = path.join(assetRoot, "index.html");
  if (!serveFile(req, res, indexPath)) {
    sendPlainText(res, 503, `Control UI assets not found at ${assetRoot}`);
  }
}

function buildUpstreamPath(pathname, search) {
  const relativePath = stripBasePath(pathname);
  const safePath = relativePath === null ? "/" : relativePath;
  return `${safePath}${search || ""}`;
}

function buildProxyHeaders(headers, rewriteOrigin) {
  const proxiedHeaders = {};

  for (const [name, value] of Object.entries(headers)) {
    if (value === undefined || name.toLowerCase() === "host") {
      continue;
    }

    if (rewriteOrigin && name.toLowerCase() === "origin") {
      proxiedHeaders[name] = `http://${gatewayHost}:${gatewayPort}`;
      continue;
    }

    proxiedHeaders[name] = value;
  }

  proxiedHeaders.host = `${gatewayHost}:${gatewayPort}`;
  return proxiedHeaders;
}

function proxyHttp(req, res, pathname, search) {
  const upstreamPath = buildUpstreamPath(pathname, search);
  const proxyReq = http.request(
    {
      headers: buildProxyHeaders(req.headers, true),
      host: gatewayHost,
      method: req.method,
      path: upstreamPath,
      port: gatewayPort,
    },
    (proxyRes) => {
      res.writeHead(proxyRes.statusCode || 502, proxyRes.headers);
      proxyRes.pipe(res);
    },
  );

  proxyReq.on("error", (error) => {
    sendPlainText(res, 502, `Gateway proxy error: ${error.message}`);
  });

  req.pipe(proxyReq);
}

function proxyUpgrade(req, socket, head) {
  const url = new URL(req.url || "/", "http://localhost");
  const upstream = net.connect(gatewayPort, gatewayHost, () => {
    const lines = [`GET ${buildUpstreamPath(url.pathname, url.search)} HTTP/${req.httpVersion}`];
    const headers = buildProxyHeaders(req.headers, true);

    headers.Connection = "Upgrade";
    headers.Upgrade = req.headers.upgrade || "websocket";

    for (const [name, value] of Object.entries(headers)) {
      if (Array.isArray(value)) {
        lines.push(`${name}: ${value.join(", ")}`);
      } else {
        lines.push(`${name}: ${value}`);
      }
    }

    lines.push("", "");
    upstream.write(lines.join("\r\n"));

    if (head.length > 0) {
      upstream.write(head);
    }

    socket.pipe(upstream).pipe(socket);
  });

  upstream.on("error", () => {
    socket.destroy();
  });

  socket.on("error", () => {
    upstream.destroy();
  });
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url || "/", "http://localhost");

  if (basePath && url.pathname === basePath) {
    res.writeHead(302, { Location: `${basePath}/` });
    res.end();
    return;
  }

  if (shouldProxyHttp(url.pathname)) {
    proxyHttp(req, res, url.pathname, url.search);
    return;
  }

  serveStatic(req, res, url.pathname);
});

server.on("upgrade", (req, socket, head) => {
  const url = new URL(req.url || "/", "http://localhost");
  if (!shouldProxyUpgrade(url.pathname)) {
    socket.destroy();
    return;
  }

  proxyUpgrade(req, socket, head);
});

server.listen(listenPort, listenHost, () => {
  console.log(`[openclaw-ui] listening on http://${listenHost}:${listenPort}${basePath || "/"}`);
});
