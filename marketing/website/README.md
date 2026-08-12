# Airframe Website

The Airframe website is a dependency-free static site. Source content, presentation, and generation stay separate so a guide or screenshot can change without rearranging the page by hand.

## Build

Requirements:

- Node.js 20 or newer
- ImageMagick for AVIF output
- `cwebp` for WebP output

From this directory:

```sh
npm test
npm run validate
npm run build
```

The preview build is written to `dist/`. Serve that directory with any static file server, for example:

```sh
python3 -m http.server 8080 --directory dist
```

`npm run build:production` adds publication gates. It intentionally fails until `domain`, `contactEmail`, and `appStoreURL` in `site.config.json` contain the real release values. It also rejects visible placeholder markers.

## Edit Inside Airframe

English content lives in `content/en/`:

- `manifest.json` owns category and guide order.
- `problems/` contains problem-led guides.
- `concepts/` contains explanations shared by more than one guide.
- `views.json` maps guides to implemented Airframe destinations.
- `glossary.json` keeps technical terms consistent.

Content is structured JSON rather than HTML. The supported blocks and reference rules are documented in `CONTRACT.md` and checked by the build. Add another locale at `content/<locale>/` and list it in `site.config.json`; the default locale keeps clean unprefixed URLs.

## Replace a screenshot

The logical asset registry is `src/assets/screenshots/screenshots.json`. Master copies live under `src/assets/screenshots/source/`.

To replace an image:

1. Replace its source file, keeping the logical filename, or update only that registry entry.
2. Run `npm run build`.

The build rediscovers intrinsic dimensions and recreates responsive AVIF and WebP derivatives. Articles continue to reference the stable logical ID. Portrait, landscape, or slightly different window sizes require no template or CSS change.

Source captures can optionally define `cropInsets` in the registry, but only for verified non-content padding. The current screenshots deliberately use no crop insets: the full captured UI is retained in the page, lightbox, and compatibility fallback.

The visible presentation frame belongs entirely to `.screenshot__link` in CSS. The caption remains outside and immediately below it. The frame uses the transparent area already present in the source captures as breathing room; it never pads, crops, masks, or rewrites the screenshot files.

Generated PNG, WebP, and AVIF filenames include a content fingerprint. Replacing or recropping a screenshot therefore produces new asset URLs instead of leaving browsers with a stale cached image.

## Replace the app icon

- `../assets/Icon-1024.png` is the detailed master for large and metadata uses.
- `../assets/Icon-128.png` is the simplified master for small website presentations.
- Website copies live as `app-icon-large.png` and `app-icon-small.png`.
- HTML presentations apply the shared `22.5%` CSS mask. Favicon and Apple touch assets are separately generated rounded derivatives because CSS is unavailable there.

## Callout presentation

Inside Airframe callouts are small plots: the colored left and bottom edges form axes with their origin at the lower-left corner, and a few subdued `--line`-colored grid lines sit behind the content. A compact tag above the title follows the app treatment: 9 px bold type inside an unfilled capsule with a semantic-colored outline and tight inner spacing. It names the type: Note, Warning, Limit, or Tip. The tag sits exactly 10 px below the top edge and 10 px above the title; its adjacent title margin is explicitly reset so general guide heading spacing cannot reopen that gap.

## Publishing notes

- Deploy only the contents of `dist/`.
- The site makes no third-party requests and uses no cookies, analytics, or local storage.
- `/privacy/` is the App Store privacy-policy destination.
- `/support/` is the App Store support destination and includes the contact details Apple expects.
- Re-run `npm test`, `npm run build:production`, and a browser review before every publication.
