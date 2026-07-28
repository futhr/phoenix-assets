import { describe, expect, it } from "vitest"
import { highlight, resolveLanguage, supportedLanguages } from "../src/highlighter.js"

describe("code highlighting", () => {
  it("resolves fence languages and their aliases", () => {
    expect(resolveLanguage("elixir")).toBe("elixir")
    expect(resolveLanguage("TypeScript")).toBe("typescript")
    expect(resolveLanguage("exs")).toBe("elixir")
    expect(resolveLanguage("sh")).toBe("bash")
    expect(resolveLanguage("brainfuck")).toBeNull()
    expect(supportedLanguages).toContain("svelte")
  })

  // The JavaScript regex engine cannot express every Oniguruma pattern, so a
  // grammar we list is not a grammar we can necessarily load. Compiling all of
  // them is the only way to know the declared set is honest.
  it.each(supportedLanguages)("highlights %s under the JavaScript engine", async (language) => {
    const html = await highlight("ok", language)
    expect(html).toMatch(/^<pre class="shiki/)
  })

  it("emits both themes as custom properties rather than baked-in colours", async () => {
    const html = await highlight("const ok = true", "typescript")
    expect(html).toContain("--shiki-light")
    expect(html).toContain("--shiki-dark")
    expect(html).not.toMatch(/color:#[0-9a-f]{6}/i)
  })

  it("returns null for a language it has no grammar for", async () => {
    expect(await highlight("hello", "text")).toBeNull()
    expect(await highlight("hello", "cobol")).toBeNull()
  })
})
