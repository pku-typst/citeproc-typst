import { defineConfig } from "astro/config";
import svelte from "@astrojs/svelte";

export default defineConfig({
  integrations: [svelte()],
  site: "https://lucifer1004.github.io",
  base: "/citeproc-typst",
  outDir: "../docs",
  build: {
    assets: "assets",
  },
});
