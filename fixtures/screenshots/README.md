# Screenshot Fixtures

`Basher Tuning.airframe` is the private, curated source document for Airframe screenshot journeys. It is tracked through Git LFS. The five portable presets beside it establish reusable analysis states; later journey automation remains responsible for window geometry, panels, scrolling, timeline position, graph viewport, and Map camera.

Build and validate:

```sh
tools/screenshot-fixtures/build.sh
tools/screenshot-fixtures/validate.sh
```

The builder verifies source SHA-256 values and publication approval before copying validated log and configuration blobs. It reads stable, ignored snapshots from `fixtures/logs/Screenshot Sources/`; only the resulting central document is versioned. Refresh those local snapshots from the approved originals and update a hash only after reviewing the replacement source and its visible privacy-sensitive data.

The document fixes the aircraft presentation to a 5-inch freestyle propeller size and classic Quad X layout. `Long Range Test` overrides the document default with the 6–7-inch Long Range profile. Its visible flights are `Baseline Flight`, `Filter Tune`, `PID Tune`, `Long Range Test`, `CHIRP Tune`, and `Motor Setup Check`.

The CHIRP validator performs a full decode. The approved 85-second source is a legacy phase-only recording with voltage and current data, so it is accepted only when Airframe reports it as analysis-available, its duration is at least 80 seconds, and its Power overview is complete. Use the builder's `inventory` command to inspect replacement Airframe documents or raw Blackbox logs before changing that source.

`manifest.json` is the durable role and future-UI-state contract. A `mapCamera` latitude or longitude of `0` is an explicit unresolved sentinel: replace it with an approved coordinate after visually choosing the final route framing. Do not capture or publish the Map journey while either value remains unresolved.

Screenshot runs must open a temporary copy of the LFS document. Never open the committed master for a mutable run.
