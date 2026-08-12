import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtemp, mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, relative } from "node:path";
import test from "node:test";
import { BuildError, buildSite, fillTemplate, imageDimensions, loadProject, renderBlocks, validateProject } from "../scripts/lib/engine.mjs";

const write = async (root, path, value) => {
  const target = join(root, path); await mkdir(dirname(target), { recursive: true });
  await writeFile(target, typeof value === "string" || Buffer.isBuffer(value) ? value : `${JSON.stringify(value, null, 2)}\n`);
};

function png(width, height) {
  const value = Buffer.alloc(33); Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]).copy(value); value.writeUInt32BE(13, 8); value.write("IHDR", 12); value.writeUInt32BE(width, 16); value.writeUInt32BE(height, 20); return value;
}

const reviewedAgainst = { appVersion: "1.0.0", betaflightVersion: "2026.6.1", reviewDate: "2026-08-11" };
const source = { label: "Airframe source", path: "Airframe/README.md" };

async function fixture() {
  const root = await mkdtemp(join(tmpdir(), "airframe-site-"));
  const config = { product: { name: "Airframe", subtitle: "A Blackbox Log Analyzer", slogan: "Every flight tells a story." }, defaultLocale: "en", locales: ["en"], releaseState: "prerelease", domain: null, contactEmail: null, appStoreURL: null, discordURL: "https://discord.gg/example", company: { legalName: "Example GmbH", address: ["Main Street 1", "Berlin"], registerCourt: "Court", registerNumber: "HRB 1", representedBy: "A Pilot", representativeAddress: [], phone: "+49 30 123", vatId: "DE1" }, privacy: { hostingProvider: "Host", serverLogRetentionDays: 7, analytics: false, cookies: false, localStorage: false } };
  await write(root, "site.config.json", config);
  await write(root, "src/assets/screenshots/screenshots.json", [
    { id: "wide", source: "wide.png", alt: "Wide screenshot", caption: "Wide", gallery: "analysis" },
    { id: "tall", source: "tall.png", alt: "Tall screenshot", caption: "Tall", gallery: "analysis" }
  ]);
  await write(root, "src/assets/screenshots/source/wide.png", png(1600, 900));
  await write(root, "src/assets/screenshots/source/tall.png", png(900, 1600));
  await write(root, "content/en/manifest.json", { locale: "en", title: "Inside Airframe", description: "Guides", categories: [{ id: "flight", title: "Flight", summary: "Flight guides" }], problems: ["first-problem", "second-problem"] });
  await write(root, "content/en/views.json", { views: [{ id: "graph", name: "Graph", path: "Document → Graph", summary: "Inspect signals.", availability: "1.0", sourcePaths: ["Airframe/Graph.swift"] }] });
  await write(root, "content/en/glossary.json", { entries: [{ id: "gyro", term: "Gyro", definition: "Rotation sensor", aliases: [], source }] });
  await write(root, "content/en/concepts/sampling.json", { id: "sampling", title: "Sampling", summary: "Recorded measurements.", blocks: [{ type: "paragraph", text: "Samples form a signal." }], sources: [source], reviewedAgainst });
  const allBlocks = [
    { type: "lead", text: "Start here." }, { type: "paragraph", text: "Read the evidence." }, { type: "heading", level: 2, title: "Inspect" },
    { type: "list", style: "bulleted", items: ["One", "Two"] }, { type: "list", style: "numbered", items: ["First"] },
    { type: "steps", items: [{ title: "Open", text: "Open the log." }] }, { type: "callout", tone: "tip", title: "Tip", text: "Use a clean flight." },
    { type: "image", asset: "wide" }, { type: "gallery", assets: ["wide", "tall"] },
    { type: "table", caption: "Values", columns: ["Signal", "Meaning"], rows: [["gyro", "rotation"]] },
    { type: "formula", expression: "x = y", explanation: "A simple relation.", variables: [{ symbol: "x", meaning: "result" }] },
    { type: "viewPath", view: "graph", steps: ["Select Graph"] }, { type: "conceptReference", concept: "sampling" },
    { type: "relatedProblems", problems: ["second-problem"] }, { type: "sources" }
  ];
  await write(root, "content/en/problems/first.json", { id: "first-problem", slug: "first-problem", status: "published", category: "Flight", order: 1, title: "First problem", summary: "Solve the first problem.", questions: ["What happened?"], viewPaths: ["graph"], concepts: ["sampling"], blocks: allBlocks, sources: [source], reviewedAgainst });
  await write(root, "content/en/problems/second.json", { id: "second-problem", slug: "second-problem", status: "published", category: "Flight", order: 2, title: "Second problem", summary: "Solve another problem.", questions: ["What next?"], viewPaths: [], concepts: [], blocks: [{ type: "paragraph", text: "Answer." }], sources: [source], reviewedAgainst });
  const templates = {
    "src/layouts/base.html": "<!doctype html><html lang=\"{{lang}}\"><head><title>{{title}}</title><meta name=\"description\" content=\"{{description}}\"><link rel=\"canonical\" href=\"{{canonical}}\"><link rel=\"stylesheet\" href=\"{{assetPrefix}}site.css\"></head><body class=\"{{bodyClass}}\">{{header}}<main>{{main}}</main>{{footer}}{{lightbox}}</body></html>",
    "src/components/header.html": "<header><a href=\"{{homeURL}}\">{{productName}}</a><a href=\"{{navInsideURL}}\">Inside</a><a href=\"{{navSupportURL}}\">Support</a></header>",
    "src/components/footer.html": "<footer><a href=\"{{homeURL}}\">Home</a><a href=\"{{insideURL}}\">Inside</a><a href=\"{{privacyURL}}\">Privacy</a><a href=\"{{imprintURL}}\">Imprint</a><a href=\"{{supportURL}}\">Support</a><a href=\"{{acknowledgementsURL}}\">Thanks</a>{{year}} {{companyName}}</footer>",
    "src/components/screenshot.html": "<figure data-gallery=\"{{gallery}}\" data-asset=\"{{assetId}}\"><a href=\"{{fullURL}}\"><picture>{{pictureSources}}<img src=\"{{fallbackURL}}\" width=\"{{width}}\" height=\"{{height}}\" alt=\"{{alt}}\"></picture></a><figcaption>{{caption}}</figcaption></figure>",
    "src/components/lightbox.html": "<dialog aria-label=\"Screenshot viewer\"></dialog>",
    "src/pages/landing.html": "<h1>{{productName}}</h1><p>{{subtitle}} {{slogan}}</p>{{primaryCTA}}{{heroScreenshot}}{{featureSections}}{{insideAirframeTeasers}}",
    "src/pages/support.html": "<h1>Support</h1>{{supportContact}}<a href=\"{{discordURL}}\">Discord</a>",
    "src/pages/privacy.html": "<h1>Privacy</h1>{{companyName}}{{contactDisplay}}{{hostingProvider}}{{serverLogRetentionDays}}",
    "src/pages/imprint.html": "<h1>Imprint</h1>{{companyDetails}}{{contactDisplay}}",
    "src/pages/acknowledgements.html": "<h1>Acknowledgements</h1>",
    "src/pages/inside-index.html": "<h1>Inside Airframe</h1>{{insideAirframeGroups}}",
    "src/pages/inside-problem.html": "<article>{{articleHeader}}{{articleBody}}{{relatedProblems}}</article>"
  };
  for (const [path, value] of Object.entries(templates)) await write(root, path, value);
  await write(root, "src/assets/site.css", "body { color: black; }\n");
  return { root, config };
}

async function digestTree(root) {
  const entries = [];
  async function visit(path) { for (const entry of (await readdir(path, { withFileTypes: true })).sort((a, b) => a.name.localeCompare(b.name))) entry.isDirectory() ? await visit(join(path, entry.name)) : entries.push(join(path, entry.name)); }
  await visit(root); const hash = createHash("sha256"); for (const path of entries) hash.update(relative(root, path)).update(await readFile(path)); return hash.digest("hex");
}

test("discovers mismatched PNG aspect ratios without changing source assets", async () => {
  const wide = png(1600, 900); const tall = png(900, 1600); const before = Buffer.from(wide);
  assert.deepEqual(imageDimensions(wide, "wide.png"), { width: 1600, height: 900 });
  assert.deepEqual(imageDimensions(tall, "tall.png"), { width: 900, height: 1600 });
  assert.deepEqual(wide, before);
});

test("renders every supported block with per-image intrinsic dimensions", async () => {
  const { root } = await fixture(); const project = await validateProject(await loadProject(root)); const data = project.locales.en; const problem = data.problems.find(item => item.id === "first-problem");
  const assets = new Map(project.screenshots.map(shot => [shot.id, { ...shot, ...(shot.id === "wide" ? { width: 1600, height: 900 } : { width: 900, height: 1600 }), original: `/assets/screenshots/source/${shot.source}`, sources: { avif: [], webp: [] } }]));
  const html = renderBlocks(problem.blocks, { assets, templates: { screenshot: "<img src=\"{{fallbackURL}}\" width=\"{{width}}\" height=\"{{height}}\" alt=\"{{alt}}\">" }, locale: "en", defaultLocale: "en", views: new Map(data.views.map(item => [item.id, item])), concepts: new Map(data.concepts.map(item => [item.id, item])), problems: new Map(data.problems.map(item => [item.id, item])), problem });
  for (const marker of ["<p class=\"lead\">", "<ol>", "class=\"steps\"", "callout--tip", "class=\"callout__kind\">Tip", "width=\"1600\" height=\"900\"", "width=\"900\" height=\"1600\"", "<table>", "class=\"formula\"", "data-view-path=\"graph\"", "id=\"concept-sampling\"", "class=\"related-problems\""]) assert.match(html, new RegExp(marker));
  assert.doesNotMatch(html, /class=\"sources\"/);
});

test("rejects unresolved template values and broken content references", async () => {
  assert.throws(() => fillTemplate("{{known}} {{missing}}", { known: "yes" }), BuildError);
  const { root } = await fixture(); const project = await loadProject(root); project.locales.en.problems[0].blocks.push({ type: "image", asset: "missing" });
  await assert.rejects(validateProject(project), /unknown screenshot missing/);
  const invalidCrop = await loadProject(root); invalidCrop.screenshots[0].cropInsets = { top: 0, right: 0, bottom: 0, left: -1 };
  await assert.rejects(validateProject(invalidCrop), /cropInsets.left must be a non-negative integer/);
});

test("production validation enforces deployment values and placeholders", async () => {
  const { root } = await fixture(); const project = await loadProject(root);
  await assert.rejects(validateProject(project, { production: true }), /contactEmail is required for production/);
  project.config.domain = "https://airframe.app"; project.config.contactEmail = "support@airframe.app"; project.config.appStoreURL = "https://apps.apple.com/app/id1"; project.locales.en.problems[0].summary = "TODO replace";
  await assert.rejects(validateProject(project, { production: true }), /visible placeholder marker/);
});

test("preview builds are deterministic and validate generated links and accessibility", async () => {
  const { root } = await fixture(); const first = join(root, "dist-a"); const second = join(root, "dist-b");
  await buildSite(root, { output: first }); await buildSite(root, { output: second });
  assert.equal(await digestTree(first), await digestTree(second));
  const page = await readFile(join(first, "inside-airframe/first-problem/index.html"), "utf8");
  assert.match(page, /alt="Wide screenshot"/); assert.match(page, /width="1600" height="900"/);
  assert.match(page, /\/assets\/screenshots\/source\/wide-[a-f0-9]{12}\.png/);
  assert.match(await readFile(join(first, "support/index.html"), "utf8"), /Email address available before release/);
});
