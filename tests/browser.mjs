// Headless check of the built page: the Auto button must pass, at phone
// width and at 320px. Needs the system Chrome and puppeteer-core on NODE_PATH.
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const puppeteer = require(process.env.PUPPETEER_CORE || "puppeteer-core");

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const docs = path.join(root, "docs");
const stamp = fs.readFileSync(path.join(docs, "version.txt"), "utf8").trim();

function serve() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      const rel = decodeURIComponent(req.url.split("?")[0]);
      const file = path.join(docs, rel === "/" ? "index.html" : rel);
      if (rel === "/favicon.ico") {
        res.writeHead(204);
        res.end();
        return;
      }
      if (!file.startsWith(docs) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
        console.error("missing", rel);
        res.writeHead(404);
        res.end("missing");
        return;
      }
      const ext = path.extname(file);
      const type = ext === ".html" ? "text/html" : ext === ".txt" ? "text/plain" : "application/octet-stream";
      res.writeHead(200, {"Content-Type": type, "Cache-Control": "no-store"});
      res.end(fs.readFileSync(file));
    });
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

async function check(page, label) {
  const errors = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") errors.push(msg.text());
  });
  page.on("pageerror", (err) => errors.push(String(err)));
  await page.goto("http://127.0.0.1:" + port + "/", {waitUntil: "networkidle0"});
  const shown = await page.$eval("#stamp", (el) => el.textContent.trim());
  if (shown !== stamp) throw new Error(label + " stamp " + shown + " != " + stamp);
  const reply = await page.$eval("#reply", (el) => el.textContent);
  if (!reply.includes('"cmd":"look"')) throw new Error(label + " did not look");
  const corner = await page.evaluate(() => {
    const c = document.getElementById("map");
    const p = c.getContext("2d").getImageData(0, 0, 1, 1).data;
    return [p[0], p[1], p[2]];
  });
  if (!(corner[2] > corner[0] && corner[2] > corner[1])) {
    throw new Error(label + " corner pixel is not water " + corner.join(","));
  }
  await page.click("#auto");
  await page.waitForFunction(() => {
    const t = document.getElementById("autoResult").textContent;
    return t.startsWith("Auto: pass") || t.startsWith("Auto: fail");
  }, {timeout: 40000});
  const result = await page.$eval("#autoResult", (el) => el.textContent);
  if (result !== "Auto: pass") throw new Error(label + " " + result);
  const report = await page.evaluate(() => window.aiIslandReport());
  if (report.auto !== "pass") throw new Error(label + " report auto " + report.auto);
  if (report.version !== stamp) throw new Error(label + " report version");
  if (!report.browser) throw new Error(label + " report has no browser");
  if (!Array.isArray(report.commands) || report.commands.length < 5) {
    throw new Error(label + " report commands");
  }
  if (errors.length) throw new Error(label + " console " + errors.join(" | "));
  console.log(label + " Auto: pass");
}

const server = await serve();
const port = server.address().port;
const browser = await puppeteer.launch({
  executablePath: process.env.CHROME || "/usr/local/bin/google-chrome",
  headless: "new",
  args: ["--no-sandbox", "--disable-gpu"]
});
try {
  const page = await browser.newPage();
  await page.setViewport({width: 320, height: 700});
  await page.emulateMediaFeatures([{name: "prefers-reduced-motion", value: "reduce"}]);
  await check(page, "320 reduced-motion");
  await page.setViewport({width: 390, height: 844});
  await page.emulateMediaFeatures([{name: "prefers-reduced-motion", value: "no-preference"}]);
  await check(page, "390 motion");
} finally {
  await browser.close();
  server.close();
}
console.log("browser ok");
