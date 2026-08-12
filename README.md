# Airframe Workspace

This repository is the private workspace wrapper for Airframe development.

It contains private planning, coordination, reference checkouts, and local workflow files. The public project lives in the `Airframe/` submodule.

## Layout

- `Airframe/`: public Airframe app and Swift packages. This is its own repository: `git@github.com:danielkbx/airframe.git`.
- `upstreams/`: read-only reference submodules for Betaflight, Blackbox Log Viewer, Betaflight Configurator, and PIDtoolbox.
- `tools/`: workspace maintenance scripts, probes, generators, and agent-development helpers.
- `marketing/`: marketing plans, private source assets, the static website, and product-showcase material.
- `knowledge/`: factual domain research about flight dynamics, tuning, logs, protocols, and platform feasibility. It does not define the implementation.
- `fixtures/`: private development and test inputs such as representative Blackbox logs. Large/private inputs are ignored.
- `.agents/`: durable private project context for local automation and handoff.

## Commit Rules

Root workspace commits may be small and frequent. They can cover `.agents/`, `AGENTS.md`, root documentation, scripts, assets, and submodule pointer updates.

The `Airframe/` submodule has stricter rules:

- Commit only with explicit approval.
- Use normal project commit messages without attribution.
- Push only after verifying the `gh` account is `danielkbx`.

The upstream reference submodules have read-only rules:

- `upstreams/blackbox-log-viewer/` and `upstreams/betaflight/` may be fetched or pulled. Keep `upstreams/betaflight-configurator/` at its pinned workspace commit.
- Do not commit in them.
- Do not push them.
- If their submodule pointers change, commit that pointer change only in the root workspace repo.

## Fresh Clone

```bash
git clone git@github.com:danielkbx/airframe_workspace.git
cd airframe_workspace
git submodule update --init
./tools/ws-status.sh
```

## Routine Sync

```bash
./tools/ws-pull.sh
```

This updates the root repository and fast-forwards the read-only reference submodules. If reference pointers change, commit those pointer updates in the root repository.

Nested upstream submodules are intentionally not initialized by the routine workspace sync. Initialize them manually inside the upstream checkout only when a firmware-side investigation needs them.
