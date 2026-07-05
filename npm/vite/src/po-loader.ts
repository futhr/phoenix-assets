import type { Plugin } from "vite"

/**
 * Vite plugin that transforms gettext `.po` catalogs into `{ messages }` modules
 * for svelte-i18n (or any catalog consumer). Ported from the bespoke loader
 * Phoenix apps tend to hand-roll.
 */
export function poLoaderPlugin(): Plugin {
  return {
    name: "phoenix-assets:po-loader",
    enforce: "pre",
    transform(code, id) {
      const [file] = id.split("?")
      if (!file?.endsWith(".po")) return null
      return { code: `export const messages = ${JSON.stringify(parsePo(code))}`, map: null }
    },
  }
}

/**
 * Parses a gettext PO document into a `{ msgid: msgstr }` map, omitting empty and
 * `#, fuzzy` (unreviewed) entries. For plural entries only `msgstr[0]` is kept.
 * Note: `msgctxt` is not tracked, so context-disambiguated entries collapse onto
 * their bare `msgid`.
 */
export function parsePo(content: string): Record<string, string> {
  const messages: Record<string, string> = {}
  let id: string | null = null
  let str: string | null = null
  let mode: "id" | "str" | null = null
  let fuzzy = false
  let nextFuzzy = false

  const flush = () => {
    if (id && str && !fuzzy) messages[id] = str
    id = null
    str = null
  }

  for (const raw of content.split("\n")) {
    const line = raw.trim()

    if (line.startsWith("#")) {
      if (line.startsWith("#,") && /\bfuzzy\b/.test(line)) nextFuzzy = true
    } else if (line.startsWith("msgid ")) {
      flush()
      fuzzy = nextFuzzy
      nextFuzzy = false
      id = unquote(line.slice(6))
      mode = "id"
    } else if (line.startsWith("msgstr[0]")) {
      str = unquote(line.slice(line.indexOf("]") + 1).trim())
      mode = "str"
    } else if (line.startsWith("msgstr[")) {
      mode = null
    } else if (line.startsWith("msgstr ")) {
      str = unquote(line.slice(7))
      mode = "str"
    } else if (line.startsWith('"')) {
      const part = unquote(line)
      if (mode === "id") id = (id ?? "") + part
      else if (mode === "str") str = (str ?? "") + part
    } else if (line === "") {
      flush()
      mode = null
    }
  }

  flush()
  delete messages[""]
  return messages
}

function unquote(value: string): string {
  const match = value.match(/^"([\s\S]*)"$/)
  if (!match) return value
  return (match[1] ?? "").replace(/\\(.)/g, (_, c) => (c === "n" ? "\n" : c === "t" ? "\t" : c))
}
