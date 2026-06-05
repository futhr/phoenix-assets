import { describe, expect, it } from "vitest"
import { parsePo } from "../src/po-loader"

describe("parsePo", () => {
  it("parses msgid/msgstr pairs, skipping the header and empty translations", () => {
    const po = [
      'msgid ""',
      'msgstr ""',
      "",
      'msgid "hello"',
      'msgstr "Hello"',
      "",
      'msgid "empty"',
      'msgstr ""',
    ].join("\n")

    const messages = parsePo(po)

    expect(messages.hello).toBe("Hello")
    expect(messages.empty).toBeUndefined()
    expect(messages[""]).toBeUndefined()
  })

  it("joins multi-line message strings", () => {
    const po = ['msgid "k"', 'msgstr ""', '"line1 "', '"line2"'].join("\n")
    expect(parsePo(po).k).toBe("line1 line2")
  })

  it("unescapes quotes and newlines", () => {
    const po = ['msgid "q"', 'msgstr "a \\"b\\" c\\nd"'].join("\n")
    expect(parsePo(po).q).toBe('a "b" c\nd')
  })
})
