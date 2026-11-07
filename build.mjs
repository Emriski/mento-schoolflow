import { build } from "esbuild";
import { cp, mkdir, rm } from "node:fs/promises";

await rm("dist", { recursive: true, force: true });
await mkdir("dist/assets", { recursive: true });
await Promise.all([
  build({ entryPoints: ["src/portal.js"], outfile: "dist/assets/portal.js", bundle: true, format: "esm", platform: "browser", target: ["es2020"], minify: true }),
  build({ entryPoints: ["src/parent.js"], outfile: "dist/assets/parent.js", bundle: true, format: "esm", platform: "browser", target: ["es2020"], minify: true })
]);
for (const file of ["index.html", "portal.html", "parent.html"]) await cp(file, "dist/" + file);
