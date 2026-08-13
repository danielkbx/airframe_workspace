import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { copyFile, mkdir, readFile, readdir, rm, stat, writeFile } from "node:fs/promises";
import { basename, dirname, extname, join, relative, resolve, sep } from "node:path";

export const BLOCK_TYPES = new Set(["lead", "paragraph", "heading", "list", "steps", "callout", "image", "gallery", "table", "formula", "viewPath", "conceptReference", "relatedProblems", "sources"]);
const PLACEHOLDER = /(?:\b(?:TODO|TBD|FIXME)\b|\[PLACEHOLDER(?:[^\]]*)\]|\{\{[^{}]+\}\}|example\.(?:com|invalid))/i;
const IMAGE_WIDTHS = [640, 960, 1440];
const CALLOUT_LABELS = { note: "Note", warning: "Warning", limit: "Limit", tip: "Tip" };
const INLINE_CONTROLS = {
  presets: `<span class="inline-control"><svg viewBox="0 0 18 18" aria-hidden="true" focusable="false"><path d="M2 4.5h3m3 0h8M2 9h8m3 0h3M2 13.5h5m3 0h6"/><circle cx="6.5" cy="4.5" r="1.5"/><circle cx="11.5" cy="9" r="1.5"/><circle cx="8.5" cy="13.5" r="1.5"/></svg><span>Presets</span></span>`
};

export class BuildError extends Error {
  constructor(messages) {
    const list = Array.isArray(messages) ? messages : [messages];
    super(list.join("\n"));
    this.name = "BuildError";
    this.messages = list;
  }
}

export const escapeHTML = (value = "") => String(value).replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&#39;");
const attrs = value => escapeHTML(value);
const asArray = value => Array.isArray(value) ? value : [];
const textOf = value => typeof value === "string" ? value : value?.text ?? value?.title ?? value?.label ?? "";
const slugPattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

export function fillTemplate(template, values, name = "template") {
  const seen = new Set();
  const rendered = template.replace(/\{\{([A-Za-z][A-Za-z0-9]*)\}\}/g, (_, key) => {
    seen.add(key);
    if (!Object.hasOwn(values, key)) throw new BuildError(`${name}: missing template value {{${key}}}`);
    return String(values[key] ?? "");
  });
  const unknown = [...rendered.matchAll(/\{\{([^{}]+)\}\}/g)].map(match => match[1]);
  if (unknown.length) throw new BuildError(`${name}: unresolved template token(s): ${unknown.join(", ")}`);
  return rendered;
}

async function json(path) {
  try { return JSON.parse(await readFile(path, "utf8")); }
  catch (error) { throw new BuildError(`${path}: ${error.message}`); }
}

async function exists(path) {
  try { await stat(path); return true; } catch { return false; }
}

async function filesBelow(path) {
  if (!await exists(path)) return [];
  const output = [];
  for (const entry of (await readdir(path, { withFileTypes: true })).sort((a, b) => a.name.localeCompare(b.name))) {
    const child = join(path, entry.name);
    if (entry.isDirectory()) output.push(...await filesBelow(child));
    else output.push(child);
  }
  return output;
}

function records(value) {
  if (Array.isArray(value)) return value;
  if (Array.isArray(value?.views)) return value.views;
  if (Array.isArray(value?.entries)) return value.entries;
  return Object.entries(value ?? {}).map(([id, item]) => ({ id, ...item }));
}

function manifestIDs(manifest) {
  return asArray(manifest.problems).map(item => typeof item === "string" ? item : item.id);
}

function validateBlock(block, location, errors) {
  if (!block || typeof block !== "object" || Array.isArray(block)) return errors.push(`${location}: block must be an object`);
  if (!BLOCK_TYPES.has(block.type)) return errors.push(`${location}: unsupported block type ${JSON.stringify(block.type)}`);
  const requireText = (...keys) => {
    if (!keys.some(key => typeof block[key] === "string" && block[key].trim())) errors.push(`${location}: ${block.type} requires ${keys.join(" or ")}`);
  };
  switch (block.type) {
    case "lead": case "paragraph": requireText("text"); break;
    case "heading": requireText("title"); if (![2, 3, 4].includes(block.level)) errors.push(`${location}: heading level must be 2, 3, or 4`); break;
    case "list": if (!["bulleted", "numbered"].includes(block.style) || !asArray(block.items).length || block.items.some(item => typeof item !== "string")) errors.push(`${location}: list requires a bulleted/numbered style and string items`); break;
    case "steps": if (!asArray(block.items).length || block.items.some(item => !item?.title || !item?.text)) errors.push(`${location}: steps requires title/text items`); break;
    case "callout": requireText("text"); if (!["note", "warning", "limit", "tip"].includes(block.tone) || !block.title) errors.push(`${location}: callout requires a valid tone and title`); break;
    case "image": requireText("asset"); break;
    case "gallery": if (!asArray(block.assets).length) errors.push(`${location}: gallery requires assets`); break;
    case "table": { const columns = asArray(block.columns); if (!columns.length || !asArray(block.rows).length) errors.push(`${location}: table requires columns and rows`); if (asArray(block.rows).some(row => !Array.isArray(row) || row.length !== columns.length)) errors.push(`${location}: every table row must match the column count`); break; }
    case "formula": requireText("expression"); if (!block.explanation || !Array.isArray(block.variables) || block.variables.some(item => !item?.symbol || !item?.meaning)) errors.push(`${location}: formula requires explanation and symbol/meaning variables`); break;
    case "viewPath": requireText("view"); if (!Array.isArray(block.steps)) errors.push(`${location}: viewPath requires steps`); break;
    case "conceptReference": requireText("concept"); break;
    case "relatedProblems": if (!asArray(block.problems).length) errors.push(`${location}: relatedProblems requires problems`); break;
    case "sources": break;
  }
}

function validateSource(source, location, errors) {
  if (!source || typeof source !== "object" || !source.label) errors.push(`${location}: source requires a label`);
  if (!source?.path && !source?.url) errors.push(`${location}: source requires path or url`);
  if (source?.path && source?.url) errors.push(`${location}: source must use either path or url`);
  if (source?.url && !/^https:\/\//.test(source.url)) errors.push(`${location}: public source URL must use HTTPS`);
  if (source?.path && (source.path.startsWith("/") || source.path.split(/[\\/]/).includes(".."))) errors.push(`${location}: repository path must be relative and may not traverse upward`);
}

export async function loadProject(root) {
  const configPath = join(root, "site.config.json");
  const registryPath = join(root, "src/assets/screenshots/screenshots.json");
  const config = await json(configPath);
  const screenshots = await json(registryPath);
  const locales = {};
  for (const locale of asArray(config.locales)) {
    const localeRoot = join(root, "content", locale);
    const manifest = await json(join(localeRoot, "manifest.json"));
    const views = await json(join(localeRoot, "views.json"));
    const glossary = await json(join(localeRoot, "glossary.json"));
    const concepts = [];
    for (const path of (await filesBelow(join(localeRoot, "concepts"))).filter(path => extname(path) === ".json")) concepts.push(await json(path));
    const problems = [];
    for (const path of (await filesBelow(join(localeRoot, "problems"))).filter(path => extname(path) === ".json")) problems.push(await json(path));
    locales[locale] = { root: localeRoot, manifest, views: records(views), glossary: records(glossary), concepts, problems };
  }
  return { root, config, screenshots, locales };
}

export async function validateProject(project, { production = false, checkAssets = true } = {}) {
  const errors = [];
  const { root, config, screenshots, locales } = project;
  if (!config.defaultLocale || !asArray(config.locales).includes(config.defaultLocale)) errors.push("site.config.json: defaultLocale must be listed in locales");
  if (production) for (const key of ["domain", "contactEmail", "appStoreURL"]) if (!config[key]) errors.push(`site.config.json: ${key} is required for production`);
  const screenshotIDs = new Set();
  for (const [index, shot] of asArray(screenshots).entries()) {
    const at = `screenshots.json[${index}]`;
    if (!shot?.id || !slugPattern.test(shot.id)) errors.push(`${at}: invalid id`);
    if (screenshotIDs.has(shot?.id)) errors.push(`${at}: duplicate id ${shot.id}`);
    screenshotIDs.add(shot?.id);
    for (const key of ["source", "alt", "caption", "gallery"]) if (!String(shot?.[key] ?? "").trim()) errors.push(`${at}: ${key} is required`);
    if (shot?.cropInsets) {
      for (const side of ["top", "right", "bottom", "left"]) if (!Number.isInteger(shot.cropInsets[side]) || shot.cropInsets[side] < 0) errors.push(`${at}: cropInsets.${side} must be a non-negative integer`);
    }
    if (checkAssets && shot?.source && !await exists(join(root, "src/assets/screenshots/source", shot.source))) errors.push(`${at}: source file not found: source/${shot.source}`);
  }
  for (const [locale, data] of Object.entries(locales)) {
    if (data.manifest.locale !== locale) errors.push(`${locale}/manifest.json: locale does not match directory`);
    for (const key of ["title", "description"]) if (!String(data.manifest[key] ?? "").trim()) errors.push(`${locale}/manifest.json: ${key} is required`);
    if (!Array.isArray(data.manifest.categories)) errors.push(`${locale}/manifest.json: categories is required`);
    const views = new Map(data.views.map(view => [view.id, view]));
    const concepts = new Map(data.concepts.map(concept => [concept.id, concept]));
    const problems = new Map(data.problems.map(problem => [problem.id, problem]));
    const ordered = manifestIDs(data.manifest);
    if (new Set(ordered).size !== ordered.length) errors.push(`${locale}/manifest.json: duplicate problem id`);
    for (const id of ordered) if (!problems.has(id)) errors.push(`${locale}/manifest.json: unknown problem ${id}`);
    for (const id of problems.keys()) if (!ordered.includes(id)) errors.push(`${locale}/manifest.json: problem ${id} is not ordered by manifest`);
    const slugs = new Set();
    for (const view of data.views) for (const key of ["id", "name", "path", "summary", "availability", "sourcePaths"]) if (view[key] === undefined || view[key] === "") errors.push(`${locale}/views.json: ${view.id ?? "unknown"} requires ${key}`);
    for (const entry of data.glossary) {
      for (const key of ["id", "term", "definition", "aliases", "source"]) if (entry[key] === undefined || entry[key] === "") errors.push(`${locale}/glossary.json: ${entry.id ?? "unknown"} requires ${key}`);
      if (entry.source) validateSource(entry.source, `${locale}/glossary/${entry.id}.source`, errors);
    }
    for (const problem of data.problems) {
      const at = `${locale}/problems/${problem.id ?? "unknown"}`;
      for (const key of ["id", "slug", "status", "category", "title", "summary"]) if (problem[key] === undefined || problem[key] === "") errors.push(`${at}: ${key} is required`);
      if (!Number.isInteger(problem.order) || problem.order < 0) errors.push(`${at}: order must be a non-negative integer`);
      if (!slugPattern.test(problem.id ?? "") || !slugPattern.test(problem.slug ?? "")) errors.push(`${at}: id and slug must be lowercase kebab-case`);
      if (slugs.has(problem.slug)) errors.push(`${at}: duplicate slug ${problem.slug}`); slugs.add(problem.slug);
      if (!asArray(problem.questions).length) errors.push(`${at}: questions must not be empty`);
      for (const id of asArray(problem.viewPaths)) if (!views.has(id)) errors.push(`${at}: unknown viewPath ${id}`);
      for (const id of asArray(problem.concepts)) if (!concepts.has(id)) errors.push(`${at}: unknown concept ${id}`);
      asArray(problem.sources).forEach((source, index) => validateSource(source, `${at}.sources[${index}]`, errors));
      asArray(problem.blocks).forEach((block, index) => validateBlock(block, `${at}.blocks[${index}]`, errors));
      validateReferences(problem.blocks, { screenshotIDs, views, concepts, problems }, at, errors);
      if (!problem.reviewedAgainst || typeof problem.reviewedAgainst !== "object" || !Object.keys(problem.reviewedAgainst).length) errors.push(`${at}: reviewedAgainst must not be empty`);
    }
    for (const concept of data.concepts) {
      const at = `${locale}/concepts/${concept.id ?? "unknown"}`;
      if (!concept.id || !concept.title || !concept.summary || !Array.isArray(concept.blocks) || !Array.isArray(concept.sources) || !concept.reviewedAgainst) errors.push(`${at}: id, title, summary, blocks, sources, and reviewedAgainst are required`);
      asArray(concept.blocks).forEach((block, index) => validateBlock(block, `${at}.blocks[${index}]`, errors));
      asArray(concept.sources).forEach((source, index) => validateSource(source, `${at}.sources[${index}]`, errors));
      validateReferences(concept.blocks, { screenshotIDs, views, concepts, problems }, at, errors);
    }
  }
  if (production && PLACEHOLDER.test(JSON.stringify({ config, locales }))) errors.push("production content contains a visible placeholder marker");
  if (errors.length) throw new BuildError(errors.sort());
  return project;
}

function validateReferences(blocks, graph, at, errors) {
  for (const match of JSON.stringify(blocks).matchAll(/\[\[control:([^\]]+)\]\]/g)) {
    if (!Object.hasOwn(INLINE_CONTROLS, match[1])) errors.push(`${at}: unknown inline control ${match[1]}`);
  }
  for (const [index, block] of asArray(blocks).entries()) {
    const location = `${at}.blocks[${index}]`;
    if (block.type === "image") check(block.asset, graph.screenshotIDs, "screenshot", location, errors);
    if (block.type === "gallery") for (const id of asArray(block.assets)) check(id, graph.screenshotIDs, "screenshot", location, errors);
    if (block.type === "viewPath") check(block.view, graph.views, "viewPath", location, errors);
    if (block.type === "conceptReference") check(block.concept, graph.concepts, "concept", location, errors);
    if (block.type === "relatedProblems") for (const id of asArray(block.problems)) check(id, graph.problems, "problem", location, errors);
  }
}

function check(id, setOrMap, kind, location, errors) { if (!setOrMap.has(id)) errors.push(`${location}: unknown ${kind} ${id}`); }

export function imageDimensions(buffer, filename = "image") {
  if (buffer.length >= 24 && buffer.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
  if (buffer.length >= 30 && buffer.toString("ascii", 0, 4) === "RIFF" && buffer.toString("ascii", 8, 12) === "WEBP") {
    const kind = buffer.toString("ascii", 12, 16);
    if (kind === "VP8X") return { width: 1 + buffer.readUIntLE(24, 3), height: 1 + buffer.readUIntLE(27, 3) };
    if (kind === "VP8L") { const bits = buffer.readUInt32LE(21); return { width: 1 + (bits & 0x3fff), height: 1 + ((bits >>> 14) & 0x3fff) }; }
    if (kind === "VP8 " && buffer.subarray(23, 26).equals(Buffer.from([0x9d, 0x01, 0x2a]))) return { width: buffer.readUInt16LE(26) & 0x3fff, height: buffer.readUInt16LE(28) & 0x3fff };
  }
  if (buffer.length >= 4 && buffer[0] === 0xff && buffer[1] === 0xd8) {
    let offset = 2;
    while (offset + 8 < buffer.length) {
      if (buffer[offset] !== 0xff) { offset++; continue; }
      const marker = buffer[offset + 1];
      if ([0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf].includes(marker)) return { height: buffer.readUInt16BE(offset + 5), width: buffer.readUInt16BE(offset + 7) };
      if (marker === 0xd8 || marker === 0xd9) { offset += 2; continue; }
      const length = buffer.readUInt16BE(offset + 2); if (length < 2) break; offset += length + 2;
    }
  }
  throw new BuildError(`${filename}: unsupported or malformed PNG, JPEG, or WebP image`);
}

function command(name) { try { return execFileSync("which", [name], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim(); } catch { return null; } }

function encode(source, destination, width, format, tools) {
  const options = { stdio: "ignore" };
  if (format === "webp" && tools.cwebp) execFileSync(tools.cwebp, ["-quiet", "-metadata", "none", "-resize", String(width), "0", "-q", "82", source, "-o", destination], options);
  else if (format === "avif" && tools.avifenc) execFileSync(tools.avifenc, ["--quiet", "--ignore-exif", "--ignore-xmp", "--ignore-icc", "--min", "20", "--max", "30", "--jobs", "1", "--resize", String(width), "0", source, destination], options);
  else if (tools.magick) execFileSync(tools.magick, [source, "-strip", "-resize", `${width}x>`, "-quality", "82", destination], options);
  else return false;
  return true;
}

export async function buildScreenshots(project, outputRoot, { production = false } = {}) {
  const sourceRoot = join(project.root, "src/assets/screenshots/source");
  const targetRoot = join(outputRoot, "assets/screenshots");
  await mkdir(join(targetRoot, "source"), { recursive: true });
  const tools = { cwebp: command("cwebp"), avifenc: command("avifenc"), magick: command("magick") };
  const assets = new Map();
  const failures = [];
  for (const shot of project.screenshots) {
    const source = join(sourceRoot, shot.source);
    const originalName = basename(shot.source);
    const extension = extname(originalName);
    const preparedSource = join(targetRoot, `.prepared-${shot.id}${extension}`);
    if (shot.cropInsets) {
      if (!tools.magick) throw new BuildError(`${shot.id}: ImageMagick is required to remove the capture frame`);
      const sourceDimensions = imageDimensions(await readFile(source), source);
      const { top, right, bottom, left } = shot.cropInsets;
      const width = sourceDimensions.width - left - right;
      const height = sourceDimensions.height - top - bottom;
      if (width < 1 || height < 1) throw new BuildError(`${shot.id}: cropInsets exceed the source dimensions`);
      execFileSync(tools.magick, [source, "-crop", `${width}x${height}+${left}+${top}`, "+repage", "-strip", preparedSource], { stdio: "ignore" });
    } else await copyFile(source, preparedSource);
    const preparedBytes = await readFile(preparedSource);
    const dimensions = imageDimensions(preparedBytes, preparedSource);
    const fingerprint = createHash("sha256").update(preparedBytes).digest("hex").slice(0, 12);
    const fingerprintedOriginalName = `${basename(originalName, extension)}-${fingerprint}${extension}`;
    const publishedSource = join(targetRoot, "source", fingerprintedOriginalName);
    await copyFile(preparedSource, publishedSource);
    await rm(preparedSource);
    const result = { ...shot, ...dimensions, original: `/assets/screenshots/source/${fingerprintedOriginalName}`, sources: { webp: [], avif: [] } };
    for (const width of [...new Set([...IMAGE_WIDTHS.filter(value => value < dimensions.width), dimensions.width])].sort((a, b) => a - b)) {
      for (const format of ["avif", "webp"]) {
        const name = `${shot.id}-${fingerprint}-${width}.${format}`;
        try {
          if (encode(publishedSource, join(targetRoot, name), width, format, tools)) result.sources[format].push({ width, url: `/assets/screenshots/${name}` });
          else if (production) failures.push(`${shot.id}: no local ${format} encoder available`);
        } catch (error) { if (production) failures.push(`${shot.id}: ${format} encoding failed: ${error.message}`); }
      }
    }
    assets.set(shot.id, result);
  }
  if (failures.length) throw new BuildError(failures);
  return assets;
}

function pictureSources(asset) {
  return ["webp", "avif"].flatMap(format => asset.sources[format].length ? [`<source type="image/${format}" srcset="${asset.sources[format].map(item => `${attrs(item.url)} ${item.width}w`).join(", ")}" sizes="(min-width: 80rem) 72rem, 100vw">`] : []).join("");
}

function urlFor(locale, defaultLocale, path = "/") { return locale === defaultLocale ? path : `/${locale}${path === "/" ? "/" : path}`; }
export function renderContentText(value, context = {}) {
  const source = String(value ?? "");
  const target = urlFor(context.locale, context.defaultLocale, "/inside-airframe/airframe-document/");
  const pattern = context.problem?.id === "airframe-document"
    ? /\[\[control:([^\]]+)\]\]/g
    : /\[\[control:([^\]]+)\]\]|\bAirframe documents?\b|(?<![A-Za-z0-9_-])\.airframe(?![A-Za-z0-9_-])/g;
  const matches = [...source.matchAll(pattern)];
  if (!matches.length) return escapeHTML(source);
  let rendered = "";
  let offset = 0;
  for (const match of matches) {
    rendered += escapeHTML(source.slice(offset, match.index));
    if (match[1]) {
      if (!Object.hasOwn(INLINE_CONTROLS, match[1])) throw new BuildError(`renderer: unknown inline control ${match[1]}`);
      rendered += INLINE_CONTROLS[match[1]];
    } else {
      rendered += `<a class="document-guide-link" href="${attrs(target)}">${escapeHTML(match[0])}</a>`;
    }
    offset = match.index + match[0].length;
  }
  return rendered + escapeHTML(source.slice(offset));
}

export function renderBlocks(blocks, context) {
  const renderImage = id => {
    const asset = context.assets.get(id);
    if (!asset) throw new BuildError(`renderer: unknown screenshot ${id}`);
    return fillTemplate(context.templates.screenshot, { fullURL: asset.original, pictureSources: pictureSources(asset), fallbackURL: asset.original, width: asset.width, height: asset.height, alt: escapeHTML(asset.alt), caption: escapeHTML(asset.caption), gallery: attrs(asset.gallery), assetId: attrs(asset.id), loading: "eager" }, "components/screenshot.html");
  };
  return asArray(blocks).map(block => {
    const text = renderContentText(textOf(block), context);
    switch (block.type) {
      case "lead": return `<p class="lead">${text}</p>`;
      case "paragraph": return `<p>${text}</p>`;
      case "heading": return `<h${block.level}>${renderContentText(block.title, context)}</h${block.level}>`;
      case "list": { const tag = block.style === "numbered" ? "ol" : "ul"; return `<${tag}>${block.items.map(item => `<li>${renderContentText(item, context)}</li>`).join("")}</${tag}>`; }
      case "steps": return `<ol class="steps">${block.items.map(item => `<li><h3>${renderContentText(item.title, context)}</h3><p>${renderContentText(item.text, context)}</p></li>`).join("")}</ol>`;
      case "callout": return `<aside class="callout callout--${attrs(block.tone)}"><span class="callout__kind">${CALLOUT_LABELS[block.tone]}</span><h3>${renderContentText(block.title, context)}</h3><p>${renderContentText(block.text, context)}</p></aside>`;
      case "image": return renderImage(block.asset);
      case "gallery": return `<div class="gallery">${block.assets.map(renderImage).join("")}</div>`;
      case "table": { const headers = block.headers ?? block.columns; return `<div class="table-scroll"><table>${block.caption ? `<caption>${renderContentText(block.caption, context)}</caption>` : ""}<thead><tr>${headers.map(item => `<th scope="col">${renderContentText(textOf(item), context)}</th>`).join("")}</tr></thead><tbody>${asArray(block.rows).map(row => `<tr>${asArray(row.cells ?? row).map((cell, index) => `<${index === 0 && block.rowHeaders ? "th scope=\"row\"" : "td"}>${renderContentText(textOf(cell), context)}</${index === 0 && block.rowHeaders ? "th" : "td"}>`).join("")}</tr>`).join("")}</tbody></table></div>`; }
      case "formula": return `<figure class="formula"><code>${escapeHTML(block.expression)}</code><figcaption>${renderContentText(block.explanation, context)}</figcaption>${block.variables.length ? `<dl>${block.variables.map(item => `<dt><code>${escapeHTML(item.symbol)}</code></dt><dd>${renderContentText(item.meaning, context)}</dd>`).join("")}</dl>` : ""}</figure>`;
      case "viewPath": { const view = context.views.get(block.view); return `<aside class="view-path" data-view-path="${attrs(block.view)}"><h3>${renderContentText(view.name, context)}</h3><p>${renderContentText(view.summary, context)}</p><p class="view-path__route">${escapeHTML(view.path)}</p>${block.steps.length ? `<ol>${block.steps.map(step => `<li>${renderContentText(step, context)}</li>`).join("")}</ol>` : ""}</aside>`; }
      case "conceptReference": { const concept = context.concepts.get(block.concept); return `<section class="concept" id="concept-${attrs(concept.id)}"><h2>${renderContentText(concept.title, context)}</h2><p>${renderContentText(concept.summary, context)}</p>${renderBlocks(concept.blocks, context)}</section>`; }
      case "relatedProblems": return renderRelated(block.problems, context);
      case "sources": return "";
      default: throw new BuildError(`renderer: unsupported block type ${block.type}`);
    }
  }).join("");
}

function renderRelated(items, context) {
  return `<ul class="related-problems">${asArray(items).map(item => {
    const id = typeof item === "string" ? item : item.id;
    const problem = context.problems.get(id);
    return `<li><a href="${attrs(urlFor(context.locale, context.defaultLocale, `/inside-airframe/${problem.slug}/`))}">${escapeHTML(problem.title)}</a></li>`;
  }).join("")}</ul>`;
}

async function template(path) { return readFile(path, "utf8"); }
async function loadTemplates(root) {
  const src = join(root, "src");
  const names = ["landing", "support", "privacy", "imprint", "acknowledgements", "inside-index", "inside-problem"];
  const pages = Object.fromEntries(await Promise.all(names.map(async name => [name, await template(join(src, "pages", `${name}.html`))])));
  return { base: await template(join(src, "layouts/base.html")), header: await template(join(src, "components/header.html")), footer: await template(join(src, "components/footer.html")), screenshot: await template(join(src, "components/screenshot.html")), lightbox: await template(join(src, "components/lightbox.html")), pages };
}

async function copyTree(source, target, skip = () => false) {
  if (!await exists(source)) return;
  for (const path of await filesBelow(source)) {
    if (skip(path)) continue;
    const destination = join(target, relative(source, path));
    await mkdir(dirname(destination), { recursive: true }); await copyFile(path, destination);
  }
}

function contact(config, button = false) { return config.contactEmail ? `<a${button ? ' class="button"' : ""} href="mailto:${attrs(config.contactEmail)}">${escapeHTML(config.contactEmail)}</a>` : "Email address available before release"; }
function companyDetails(company) { return [company.legalName, ...asArray(company.address), `${company.registerCourt} · ${company.registerNumber}`, `Represented by ${company.representedBy}`, ...asArray(company.representativeAddress), company.phone, company.vatId].filter(Boolean).map(escapeHTML).join("<br>"); }

export async function buildSite(root, { production = false, output = join(root, "dist") } = {}) {
  const project = await validateProject(await loadProject(root), { production });
  const templates = await loadTemplates(root);
  await rm(output, { recursive: true, force: true }); await mkdir(output, { recursive: true });
  await copyTree(join(root, "src/assets"), join(output, "assets"), path => path.includes(`${sep}screenshots${sep}`));
  for (const name of ["favicon.ico", "apple-touch-icon.png"]) {
    const source = join(root, "src/assets/images", name);
    if (await exists(source)) await copyFile(source, join(output, name));
  }
  const assets = await buildScreenshots(project, output, { production });
  const written = [];
  const writePage = async (locale, route, pageName, values, metadata = {}) => {
    const prefix = locale === project.config.defaultLocale ? "" : `/${locale}`;
    const localized = path => `${prefix}${path}` || "/";
    const header = fillTemplate(templates.header, { homeURL: localized("/"), navInsideURL: localized("/inside-airframe/"), navSupportURL: localized("/support/"), productName: escapeHTML(project.config.product.name) }, "components/header.html");
    const footer = fillTemplate(templates.footer, { homeURL: localized("/"), insideURL: localized("/inside-airframe/"), privacyURL: localized("/privacy/"), imprintURL: localized("/imprint/"), supportURL: localized("/support/"), acknowledgementsURL: localized("/acknowledgements/"), year: "2026", companyName: escapeHTML(project.config.company.legalName) }, "components/footer.html");
    const main = fillTemplate(templates.pages[pageName], values, `pages/${pageName}.html`);
    const canonicalPath = localized(route);
    const canonical = project.config.domain ? new URL(canonicalPath, project.config.domain).href : canonicalPath;
    const html = fillTemplate(templates.base, { lang: attrs(locale), title: escapeHTML(metadata.title ?? project.config.product.name), description: attrs(metadata.description ?? project.config.product.subtitle), bodyClass: attrs(metadata.bodyClass ?? pageName), assetPrefix: "/assets/", canonical: attrs(canonical), header, main, footer, lightbox: templates.lightbox }, "layouts/base.html");
    const target = route === "/" ? join(output, prefix, "index.html") : join(output, prefix, route.slice(1), "index.html");
    await mkdir(dirname(target), { recursive: true }); await writeFile(target, `${html.trim()}\n`, "utf8"); written.push(target);
  };
  for (const [locale, data] of Object.entries(project.locales)) {
    const views = new Map(data.views.map(item => [item.id, item]));
    const concepts = new Map(data.concepts.map(item => [item.id, item]));
    const problems = new Map(data.problems.map(item => [item.id, item]));
    const ordered = manifestIDs(data.manifest).map(id => problems.get(id));
    const context = { assets, templates, locale, defaultLocale: project.config.defaultLocale, views, concepts, problems };
    const renderLandingScreenshot = (id, loading = "lazy") => {
      const asset = assets.get(id);
      if (!asset) throw new BuildError(`landing: unknown screenshot ${id}`);
      return fillTemplate(templates.screenshot, { fullURL: asset.original, pictureSources: pictureSources(asset), fallbackURL: asset.original, width: asset.width, height: asset.height, alt: escapeHTML(asset.alt), caption: escapeHTML(asset.caption), gallery: attrs(asset.gallery), assetId: attrs(asset.id), loading }, "components/screenshot.html");
    };
    const feature = (label, title, summary, asset) => assets.has(asset) ? `<article class="feature"><div class="feature__copy"><p class="eyebrow">${escapeHTML(label)}</p><h3>${renderContentText(title, context)}</h3><p>${renderContentText(summary, context)}</p></div><div class="feature__media">${renderLandingScreenshot(asset)}</div></article>` : "";
    const landingFeatures = [
      feature("Check the setup", views.get("overview")?.name ?? "Overview", views.get("overview")?.summary ?? "Review the aircraft, flight controller, and available setup evidence before deeper analysis.", "overview"),
      feature("Follow the moment", views.get("graph")?.name ?? "Graph", views.get("graph")?.summary ?? "Read the flight on one shared timeline.", "graph-playback"),
      feature("Find the noise", views.get("spectrum")?.name ?? "Spectrum", views.get("spectrum")?.summary ?? "See where vibration energy lives.", "spectrum"),
      feature("Measure the response", views.get("system-response")?.name ?? "System Response", views.get("system-response")?.summary ?? "Compare what the craft was asked to do with what it actually did.", "step-response"),
      feature("Remember the place", views.get("map")?.name ?? "Map", views.get("map")?.summary ?? "Put events back where they happened.", "map"),
      feature("Skip the file shuffle", "Flight Controller Import", "Bring logs and available configuration evidence across by USB cable, Bluetooth, or SpeedyBee Adapter 3.", "flight-controller-import")
    ].join("");
    const landingTeasers = ordered.slice(0, 6).map(item => `<article class="problem-card"><p class="eyebrow">${escapeHTML(item.category)}</p><h3><a href="${attrs(urlFor(locale, project.config.defaultLocale, `/inside-airframe/${item.slug}/`))}">${escapeHTML(item.title)}</a></h3><p>${renderContentText(item.summary, { ...context, problem: item })}</p><a class="text-link" href="${attrs(urlFor(locale, project.config.defaultLocale, `/inside-airframe/${item.slug}/`))}">Read the guide <span aria-hidden="true">→</span></a></article>`).join("");
    const screenshot = assets.get("chirp-response") ?? assets.values().next().value;
    const primaryCTA = project.config.appStoreURL ? `<a href="${attrs(project.config.appStoreURL)}">Download on the App Store</a>` : `<a href="${attrs(project.config.discordURL)}">Join the Discord</a><span class="availability">Mac first. iPhone and iPad later.</span>`;
    await writePage(locale, "/", "landing", { productName: escapeHTML(project.config.product.name), subtitle: escapeHTML(project.config.product.subtitle), slogan: escapeHTML(project.config.product.slogan), primaryCTA, heroScreenshot: screenshot ? renderLandingScreenshot(screenshot.id, "eager") : "", featureSections: landingFeatures, insideAirframeTeasers: landingTeasers }, { description: project.config.product.slogan, bodyClass: "landing" });
    const groups = new Map(); for (const problem of ordered) groups.set(problem.category, [...(groups.get(problem.category) ?? []), problem]);
    const categories = new Map(asArray(data.manifest.categories).map(category => [category.id, category]));
    await writePage(locale, "/inside-airframe/", "inside-index", { insideAirframeGroups: [...groups].map(([categoryID, items]) => {
      const category = categories.get(categoryID) ?? { title: categoryID, summary: "" };
      return `<section><header><p class="eyebrow">${escapeHTML(categoryID)}</p><h2>${renderContentText(category.title, context)}</h2><p>${renderContentText(category.summary, context)}</p></header><div class="problem-grid">${items.map(item => `<article class="problem-card"><h3><a href="${attrs(urlFor(locale, project.config.defaultLocale, `/inside-airframe/${item.slug}/`))}">${escapeHTML(item.title)}</a></h3><p>${renderContentText(item.summary, { ...context, problem: item })}</p><a class="text-link" href="${attrs(urlFor(locale, project.config.defaultLocale, `/inside-airframe/${item.slug}/`))}">Read the guide <span aria-hidden="true">→</span></a></article>`).join("")}</div></section>`;
    }).join("") }, { title: `Inside Airframe — ${project.config.product.name}`, description: "Problem-led Airframe guides." });
    for (const problem of ordered) {
      const body = renderBlocks(problem.blocks.filter(block => !["relatedProblems", "sources"].includes(block.type)), { ...context, problem });
      const relatedBlock = problem.blocks.find(block => block.type === "relatedProblems");
      await writePage(locale, `/inside-airframe/${problem.slug}/`, "inside-problem", { articleHeader: `<header><p>${escapeHTML(problem.category)}</p><h1>${renderContentText(problem.title, { ...context, problem })}</h1><p class="lead">${renderContentText(problem.summary, { ...context, problem })}</p></header>`, articleBody: body, relatedProblems: relatedBlock ? renderRelated(relatedBlock.problems, context) : "" }, { title: `${problem.title} — ${project.config.product.name}`, description: problem.summary, bodyClass: "inside-problem" });
    }
    const common = { supportContact: contact(project.config, true), discordURL: attrs(project.config.discordURL ?? ""), companyName: escapeHTML(project.config.company.legalName), contactDisplay: contact(project.config), hostingProvider: escapeHTML(project.config.privacy.hostingProvider), serverLogRetentionDays: escapeHTML(project.config.privacy.serverLogRetentionDays), companyDetails: companyDetails(project.config.company) };
    for (const [route, page] of [["/support/", "support"], ["/privacy/", "privacy"], ["/imprint/", "imprint"], ["/acknowledgements/", "acknowledgements"]]) await writePage(locale, route, page, common, { title: `${page[0].toUpperCase()}${page.slice(1)} — ${project.config.product.name}` });
  }
  await validateOutput(output, { production });
  return { output, files: written.sort() };
}

export async function validateOutput(output, { production = false } = {}) {
  const htmlFiles = (await filesBelow(output)).filter(path => extname(path) === ".html");
  const errors = [];
  for (const file of htmlFiles) {
    const html = await readFile(file, "utf8");
    if (/\{\{[^{}]+\}\}/.test(html)) errors.push(`${relative(output, file)}: unresolved template token`);
    if (production && PLACEHOLDER.test(html)) errors.push(`${relative(output, file)}: visible placeholder marker`);
    for (const match of html.matchAll(/<img\b([^>]*)>/gi)) {
      const alt = match[1].match(/\balt=(?:"([^"]*)"|'([^']*)')/i); if (!alt) errors.push(`${relative(output, file)}: image has no alt attribute`);
      if (!/\bdata-lightbox-image\b/i.test(match[1]) && (!/\bwidth=["']\d+["']/i.test(match[1]) || !/\bheight=["']\d+["']/i.test(match[1]))) errors.push(`${relative(output, file)}: image lacks intrinsic width/height`);
    }
    for (const match of html.matchAll(/\bhref=(?:"([^"]+)"|'([^']+)')/gi)) {
      const href = match[1] ?? match[2]; if (/^(?:https:|mailto:|tel:|#)/.test(href)) continue;
      if (!href.startsWith("/")) { errors.push(`${relative(output, file)}: internal link is not site-root relative: ${href}`); continue; }
      const pathname = href.split(/[?#]/)[0]; const target = pathname.endsWith("/") ? join(output, pathname, "index.html") : join(output, pathname);
      if (!await exists(target)) errors.push(`${relative(output, file)}: broken internal link ${href}`);
    }
  }
  if (errors.length) throw new BuildError(errors.sort());
}

export async function validateAt(root, options = {}) { return validateProject(await loadProject(resolve(root)), options); }
