#!/usr/bin/env node
// Generates Triviatsky question images + the app icon with Nano Banana (Gemini image API).
// Reads GEMINI_API_KEY from env or ~/.gemini/.env. Never prints the key.
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

let key = process.env.GEMINI_API_KEY;
if (!key) {
  const envFile = join(homedir(), ".gemini", ".env");
  if (existsSync(envFile)) {
    const match = readFileSync(envFile, "utf8").match(/^GEMINI_API_KEY=(.+)$/m);
    if (match) key = match[1].trim();
  }
}
if (!key) {
  console.error("ERROR: GEMINI_API_KEY not set (env or ~/.gemini/.env)");
  process.exit(1);
}

async function api(path, body) {
  const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/${path}`, {
    method: body ? "POST" : "GET",
    headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  return response.json();
}

// Pick the newest stable image model.
const list = await api("models?pageSize=1000");
if (list.error) {
  console.error("ListModels error:", list.error.message);
  process.exit(1);
}
const imageModels = (list.models ?? [])
  .map((m) => m.name.replace("models/", ""))
  .filter((n) => /image/.test(n) && !/veo|video|embed/.test(n));
// Prefer pro > flash > flash-lite, newest version first, stable over preview.
const rank = (n) =>
  (/-pro-/.test(n) ? 200 : /lite/.test(n) ? 0 : 100) +
  parseFloat(n.match(/gemini-([\d.]+)/)?.[1] ?? 0) * 10 +
  (/preview|exp/.test(n) ? -5 : 0);
const model = imageModels.sort((a, b) => rank(a) - rank(b)).pop();
if (!model) {
  console.error("No image-capable model available. Models:", imageModels);
  process.exit(1);
}
console.log("Using model:", model);

async function generate(outPath, prompt) {
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const result = await api(`models/${model}:generateContent`, {
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { responseModalities: ["IMAGE"] },
      });
      const part = (result.candidates?.[0]?.content?.parts ?? []).find((p) => p.inlineData);
      if (!part) {
        throw new Error(
          result.error?.message ?? "no image in response: " + JSON.stringify(result).slice(0, 200)
        );
      }
      mkdirSync(dirname(outPath), { recursive: true });
      writeFileSync(outPath, Buffer.from(part.inlineData.data, "base64"));
      console.log("  ✓", outPath);
      return true;
    } catch (error) {
      console.error(`  attempt ${attempt} failed for ${outPath}: ${error.message}`);
      await new Promise((r) => setTimeout(r, 4000));
    }
  }
  console.error("  ✗ FAILED:", outPath);
  return false;
}

const STYLE =
  "Photorealistic, high quality travel photograph, natural daylight, 4:3 landscape orientation. " +
  "Absolutely no text, no words, no watermarks, no people in the foreground.";

const jobs = [
  ["Sources/Resources/TriviaImages/pt-br/brasilia.jpg",
    `The National Congress building in Brasília, Brazil: the iconic modernist twin towers with the dome and bowl designed by Oscar Niemeyer, wide plaza, clear blue sky. ${STYLE}`],
  ["Sources/Resources/TriviaImages/pt-br/amazonia.jpg",
    `Aerial view of the Amazon rainforest in Brazil, dense green jungle canopy stretching to the horizon with a wide winding brown river, morning mist. ${STYLE}`],
  ["Sources/Resources/TriviaImages/pt-br/rio-olympics.jpg",
    `Rio de Janeiro, Brazil: view over Guanabara Bay with Sugarloaf Mountain and the city, celebratory fireworks bursting in the evening sky over a lit stadium in the distance. ${STYLE}`],
  ["Sources/Resources/TriviaImages/uk/kyiv.jpg",
    `Kyiv, Ukraine: skyline with the golden domes of St. Sophia Cathedral and its white bell tower, historic city center, warm afternoon light. ${STYLE}`],
  ["Sources/Resources/TriviaImages/uk/yalpuh.jpg",
    `Lake Yalpuh in the Bessarabia region of southern Ukraine: a vast calm freshwater lake at golden sunset, reeds in the foreground, flat steppe shoreline. ${STYLE}`],
  ["Sources/Resources/TriviaImages/uk/hoverla.jpg",
    `Mount Hoverla, the highest peak of the Ukrainian Carpathians: rounded green-brown summit above alpine meadows, a hiking trail, dramatic clouds. ${STYLE}`],
];

let failures = 0;
for (const [out, prompt] of jobs) {
  if (!(await generate(join(root, out), prompt))) failures++;
}

// Downscale trivia photos for the bundle.
for (const [out] of jobs) {
  const p = join(root, out);
  if (existsSync(p)) {
    execFileSync("sips", ["--resampleWidth", "800", "-s", "format", "jpeg", "-s", "formatOptions", "80", p, "--out", p], { stdio: "ignore" });
  }
}

const iconPath = join(root, "Sources/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png");
const iconOK = await generate(
  iconPath,
  "iOS app icon, flat vector illustration style, perfectly square, full-bleed with NO rounded corners and NO border. " +
    "Soviet constructivist propaganda poster aesthetic: very dark navy background (hex 0E0E1A) with a subtle radiating " +
    "sunburst of dark red rays from the center, and in the center one glossy golden letter tile (rounded square game tile, " +
    "hex C8A830 gold) embossed with the single Cyrillic letter Я in bold dark navy, with a small gold five-pointed star " +
    "above the tile. Clean, minimal, bold shapes, high contrast. No other text."
);
if (iconOK) {
  execFileSync("sips", ["--resampleHeightWidth", "1024", "1024", "-s", "format", "png", iconPath, "--out", iconPath], { stdio: "ignore" });
}

console.log(failures === 0 && iconOK ? "All assets generated." : `Finished with ${failures + (iconOK ? 0 : 1)} failure(s).`);
process.exit(failures === 0 && iconOK ? 0 : 1);
