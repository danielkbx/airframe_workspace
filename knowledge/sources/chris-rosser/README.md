# Chris Rosser Betaflight 4.5 Tuning Sources

- Status: private research archive
- Author: Chris Rosser
- Acquired: 2026-08-05 from user-provided downloads
- Distribution: private Airframe workspace only; do not redistribute or copy into the public `Airframe/` repository

These slide decks accompany Chris Rosser's Betaflight 4.5 tuning masterclass. Public provenance is available through his Patreon publication and companion videos:

- [Betaflight 4.5 Filter Tuning](https://www.youtube.com/watch?v=E3s5XYk3M74), published 2024-03-29
- [Betaflight 4.5 PID Tuning](https://www.youtube.com/watch?v=1oYoVE4xu1U), published 2024-04-05
- [Betaflight 4.5 Filter Tuning Guide Patreon post](https://www.patreon.com/chris_rosser/posts/betaflight-4-5-100721044), published 2024-03-20

## Integrity Register

| Document | Archived file | Pages | Created | SHA-256 |
|---|---|---:|---|---|
| BF 4.5 Filter Tuning | `BF-4.5-Filter-Tuning.pdf` | 21 | 2024-03-20 | `7fa5aea69cf8cd9625e5d85096bb276a6b22721abdb0876b08e9b18b6be826b3` |
| BF 4.5 PID Tuning | `BF-4.5-PID-Tuning.pdf` | 62 | 2024-03-29 | `0fbe543ec991d3c2408b2791706b55fed98a2bd91d8088b7dc8fbd33ce4d014e` |

The Filter deck has no embedded PDF `Author` value. The PID deck's embedded PDF `Author` value is `KateDOS`; both list Microsoft PowerPoint LTSC as creator and producer. Public publication evidence establishes Chris Rosser as the author of the masterclass material, so the metadata observation is retained as production provenance rather than treated as conflicting authorship.

The PDFs are stored in the private repository through Git LFS. The scoped `.gitattributes` rule applies only to PDFs under `knowledge/sources/`; the files must never be copied into the public `Airframe/` repository.
