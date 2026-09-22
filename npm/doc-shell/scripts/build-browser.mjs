import { fileURLToPath } from "node:url"
import { build } from "vite"

const root = fileURLToPath(new URL("..", import.meta.url))
const output = fileURLToPath(new URL("../../../priv/doc_shell", import.meta.url))

await build({
  root,
  configFile: false,
  publicDir: false,
  build: {
    emptyOutDir: true,
    minify: "esbuild",
    outDir: output,
    sourcemap: false,
    target: "es2022",
    lib: {
      entry: fileURLToPath(new URL("../src/browser/entry.ts", import.meta.url)),
      formats: ["es"],
      fileName: () => "doc-shell-browser.js",
      cssFileName: "doc-shell",
    },
    rollupOptions: {
      output: {
        assetFileNames: (asset) =>
          asset.names?.some((name) => name.endsWith(".css"))
            ? "doc-shell.css"
            : "[name]-[hash][extname]",
      },
    },
  },
})
