#!/usr/bin/env node
import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import { createServer } from "node:http";
import { extname, isAbsolute, relative, resolve } from "node:path";

const root = resolve(import.meta.dirname, "..", "dist");
const port = Number.parseInt(process.env.PORT ?? "8080", 10);

if (!Number.isInteger(port) || port < 1 || port > 65_535) throw new Error(`Invalid PORT: ${process.env.PORT}`);

const contentTypes = new Map([
  [".avif", "image/avif"],
  [".css", "text/css; charset=utf-8"],
  [".html", "text/html; charset=utf-8"],
  [".ico", "image/x-icon"],
  [".js", "text/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".png", "image/png"],
  [".svg", "image/svg+xml"],
  [".webp", "image/webp"]
]);

const server = createServer(async (request, response) => {
  if (request.method !== "GET" && request.method !== "HEAD") {
    response.writeHead(405, { Allow: "GET, HEAD" }).end();
    return;
  }

  try {
    const pathname = decodeURIComponent(new URL(request.url ?? "/", "http://localhost").pathname);
    let file = resolve(root, `.${pathname}`);
    const pathWithinRoot = relative(root, file);

    if (pathWithinRoot.startsWith("..") || isAbsolute(pathWithinRoot)) {
      response.writeHead(403).end("Forbidden\n");
      return;
    }

    if ((await stat(file)).isDirectory()) file = resolve(file, "index.html");
    const metadata = await stat(file);

    response.writeHead(200, {
      "Content-Length": metadata.size,
      "Content-Type": contentTypes.get(extname(file)) ?? "application/octet-stream"
    });
    if (request.method === "HEAD") response.end();
    else createReadStream(file).pipe(response);
  } catch {
    response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" }).end("Not found\n");
  }
});

server.listen(port, "127.0.0.1", () => {
  console.log(`Serving ${root} at http://localhost:${port}`);
});
