#!/usr/bin/env node
import { resolve } from "node:path";
import { BuildError, buildSite, validateAt } from "./lib/engine.mjs";

const [command = "build", ...flags] = process.argv.slice(2);
const production = flags.includes("--production");
const root = resolve(import.meta.dirname, "..");

try {
  if (command === "build") {
    const result = await buildSite(root, { production });
    console.log(`Built ${result.files.length} pages in ${result.output}`);
  } else if (command === "validate") {
    await validateAt(root, { production, checkAssets: true });
    console.log(`Validated ${root}${production ? " for production" : ""}`);
  } else throw new BuildError(`Unknown command: ${command}`);
} catch (error) {
  console.error(error instanceof BuildError ? error.message : error.stack);
  process.exitCode = 1;
}
