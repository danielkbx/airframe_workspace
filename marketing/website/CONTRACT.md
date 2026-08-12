# Airframe Website Contract

This file is the integration boundary for the website workstreams. Generated files must never be edited by hand.

## URLs and output

- Source locale paths use `content/<locale>/`.
- The default locale is emitted without a locale prefix.
- Pages are directory-style URLs: `/inside-airframe/<problem-slug>/`, `/privacy/`, `/imprint/`, `/support/`, and `/acknowledgements/`.
- The build output is `dist/` and must be byte-for-byte deterministic for identical inputs.
- All internal links must be relative to the site root and validated after rendering.

## Content graph

`content/en/manifest.json` defines navigation and problem ordering. The locale also contains `views.json`, `glossary.json`, reusable documents below `concepts/`, and problem guides below `problems/`.

Every problem guide has these fields:

- `id`, `slug`, `status`, `category`, `order`, `title`, `summary`
- `questions`: short problem statements a pilot may actually ask
- `viewPaths`: IDs declared in `views.json`
- `concepts`: IDs declared by reusable concept documents
- `blocks`: ordered structured content
- `sources`: evidence references with a label and repository-relative path or public URL
- `reviewedAgainst`: app version, Betaflight version or commit, and review date where applicable

Supported block types are `lead`, `paragraph`, `heading`, `list`, `steps`, `callout`, `image`, `gallery`, `table`, `formula`, `viewPath`, `conceptReference`, `relatedProblems`, and `sources`. Content JSON never contains raw HTML.

Their exact shapes are:

- `lead`: `{ "type": "lead", "text": "…" }`
- `paragraph`: `{ "type": "paragraph", "text": "…" }`
- `heading`: `{ "type": "heading", "level": 2, "title": "…" }`
- `list`: `{ "type": "list", "style": "bulleted|numbered", "items": ["…"] }`
- `steps`: `{ "type": "steps", "items": [{ "title": "…", "text": "…" }] }`
- `callout`: `{ "type": "callout", "tone": "note|warning|limit|tip", "title": "…", "text": "…" }`
- `image`: `{ "type": "image", "asset": "logical-screenshot-id" }`
- `gallery`: `{ "type": "gallery", "assets": ["logical-screenshot-id"] }`
- `table`: `{ "type": "table", "caption": "optional", "columns": ["…"], "rows": [["…"]] }`
- `formula`: `{ "type": "formula", "expression": "…", "explanation": "…", "variables": [{ "symbol": "…", "meaning": "…" }] }`
- `viewPath`: `{ "type": "viewPath", "view": "view-id", "steps": ["…"] }`
- `conceptReference`: `{ "type": "conceptReference", "concept": "concept-id" }`
- `relatedProblems`: `{ "type": "relatedProblems", "problems": ["problem-id"] }`
- `sources`: `{ "type": "sources" }`, retained as internal verification metadata and never rendered publicly

Concept documents use `id`, `title`, `summary`, `blocks`, `sources`, and `reviewedAgainst`. `views.json` contains a `views` array whose entries use `id`, `name`, `path`, `summary`, `availability`, and `sourcePaths`. The manifest uses `locale`, `title`, `description`, ordered `categories`, and an ordered `problems` ID array. The glossary contains `entries` with `id`, `term`, `definition`, `aliases`, and `source`.

## Templates and renderer

- `src/layouts/base.html` is the shared document shell.
- Page fragments live below `src/pages/`; the renderer wraps them in the base layout.
- Reusable presentation fragments live below `src/components/`.
- Layout placeholders use `{{name}}`. The renderer owns escaping for data; repository templates are trusted HTML.
- Required base placeholders: `lang`, `title`, `description`, `bodyClass`, `assetPrefix`, `canonical`, `header`, `main`, `footer`, and `lightbox`.
- Presentation code may use semantic hooks (`data-*` attributes and documented class names), but may not assume a screenshot aspect ratio.

The component and page fragment placeholder interface is:

- Header: `homeURL`, `navInsideURL`, `navSupportURL`, `productName`
- Footer: `homeURL`, `insideURL`, `privacyURL`, `imprintURL`, `supportURL`, `acknowledgementsURL`, `year`, `companyName`
- Screenshot: `fullURL`, `pictureSources`, `fallbackURL`, `width`, `height`, `alt`, `caption`, `gallery`, `assetId`
- Landing: `productName`, `subtitle`, `slogan`, `primaryCTA`, `heroScreenshot`, `featureSections`, `insideAirframeTeasers`
- Support: `supportContact`, `discordURL`
- Privacy: `companyName`, `contactDisplay`, `hostingProvider`, `serverLogRetentionDays`
- Imprint: `companyDetails`, `contactDisplay`
- Inside Airframe index: `insideAirframeGroups`
- Inside Airframe problem: `articleHeader`, `articleBody`, `relatedProblems`

Any unknown or unfilled placeholder is a build error.

## Screenshot assets

`src/assets/screenshots/screenshots.json` is the only screenshot registry. Its entries use:

```json
{
  "id": "graph-playback",
  "source": "graph-playback.png",
  "alt": "Airframe Graph showing gyro, motor and setpoint signals during playback",
  "caption": "Follow recorded signals and craft state on the same timeline.",
  "gallery": "flight-analysis"
}
```

Content references only the logical `id`. The asset build discovers the current source width and height, creates replaceable WebP and AVIF derivatives, copies the original PNG, and writes intrinsic dimensions into rendered markup. Full screenshots are never cropped. Optional `focalPoint` metadata applies only to deliberately cropped thumbnails.

The root agent exclusively owns `src/assets/screenshots/**`; Presentation owns other `src/assets/**` areas.

## Site configuration and publication gates

`site.config.json` supplies product metadata and deployment-dependent values. A preview build may render explanatory prerelease fallbacks. A production build must fail while `domain`, `contactEmail`, or `appStoreURL` is null, or when visible placeholder markers remain.

The website makes no third-party requests, sets no cookies, and uses no local storage. Fonts and scripts are self-hosted or use platform resources.
