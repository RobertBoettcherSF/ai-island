// Headless check of the built page: the Auto button must pass, at phone
// width and at 320px. Needs the system Chrome and puppeteer-core on NODE_PATH.
import http from "node:http";
import fs from "node:fs";
import os from "node:os";
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

async function check(page, label, query) {
  const errors = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") errors.push(msg.text());
  });
  page.on("pageerror", (err) => errors.push(String(err)));
  await page.goto("http://127.0.0.1:" + port + "/" + (query || ""), {waitUntil: "networkidle0"});
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
  const seeds = await page.evaluate(() => ({
    island: document.getElementById("islandSeed").value,
    pop: document.getElementById("popSeed").value
  }));
  if (query && query.includes("island=42") && (seeds.island !== "42" || seeds.pop !== "7")) {
    throw new Error(label + " seeds " + seeds.island + " " + seeds.pop);
  }
  if (!query && seeds.island !== "539365668") {
    throw new Error(label + " default island seed " + seeds.island);
  }
  await page.click("#speed10");
  const pressed = await page.$eval("#speed10", (el) => el.getAttribute("aria-pressed"));
  if (pressed !== "true") throw new Error(label + " speed button");
  const downloadDir = fs.mkdtempSync(path.join(os.tmpdir(), "island-run-"));
  const client = await page.createCDPSession();
  await client.send("Page.setDownloadBehavior", {behavior: "allow", downloadPath: downloadDir});
  await page.click("#auto");
  await page.waitForFunction(() => document.getElementById("auto").textContent === "Stop", {timeout: 10000});
  await page.click("#speed100");
  await page.waitForFunction(() => {
    const text = document.getElementById("hungerLine").textContent;
    const match = text.match(/turn (\d+)/);
    return match && Number(match[1]) >= 100;
  }, {timeout: 20000});
  const running = await page.evaluate(() => window.aiIslandReport());
  if (running.auto !== "running") throw new Error(label + " F9 while running " + running.auto);
  if (typeof running.island !== "number" || typeof running.pop !== "number") {
    throw new Error(label + " F9 seeds");
  }
  await page.click("#auto");
  await page.waitForFunction(() => document.getElementById("auto").textContent === "Auto", {timeout: 10000});
  const file = await waitForRun(downloadDir);
  const run = JSON.parse(fs.readFileSync(file, "utf8"));
  if (run.version !== stamp) throw new Error(label + " run version " + run.version);
  if (!run.commit) throw new Error(label + " run commit");
  if (!(run.totalTurns >= 100)) throw new Error(label + " totalTurns " + run.totalTurns);
  for (const key of ["population", "births", "deaths", "island", "pop"]) {
    if (typeof run[key] !== "number") throw new Error(label + " missing " + key);
  }
  for (const side of ["start", "end"]) {
    for (const trait of ["speed", "sight", "metabolism", "fertility"]) {
      if (typeof run[side][trait] !== "number") throw new Error(label + " " + side + " " + trait);
    }
  }
  if (!Array.isArray(run.history) || run.history.length < 1 || run.history[0].turn !== 100) {
    throw new Error(label + " history");
  }
  if (typeof run.history[0].population !== "number" || typeof run.history[0].speed !== "number") {
    throw new Error(label + " history traits");
  }
  if (!Array.isArray(run.commands) || run.commands.length < 1) throw new Error(label + " commands");
  console.log(label + " stopped after " + run.totalTurns + " turns, population " + run.population);
  if (errors.length) throw new Error(label + " console " + errors.join(" | "));
}

function waitForRun(dir) {
  return new Promise((resolve, reject) => {
    const started = Date.now();
    const tick = () => {
      const names = fs.readdirSync(dir).filter((name) => name.endsWith(".json"));
      if (names.length) {
        resolve(path.join(dir, names[0]));
        return;
      }
      if (Date.now() - started > 10000) {
        reject(new Error("no ai-island-run.json in " + dir));
        return;
      }
      setTimeout(tick, 100);
    };
    tick();
  });
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
  await check(page, "320 reduced-motion", "");
  await page.setViewport({width: 390, height: 844});
  await page.emulateMediaFeatures([{name: "prefers-reduced-motion", value: "no-preference"}]);
  await check(page, "390 motion", "?island=42&pop=7");
} finally {
  await browser.close();
  server.close();
}
console.log("browser ok");
