import { describe, expect, it } from "vitest"
import { shapeParser } from "../src/electric/parser"

describe("generated row integer decoding", () => {
  it.each(["0", "-3", "42", "9007199254740991", "-9007199254740991"])(
    "preserves exact safe integer %s",
    (value) => {
      const parsed = shapeParser.int8(value)
      expect(parsed).toBeTypeOf("number")
      expect(BigInt(parsed)).toBe(BigInt(value))
    },
  )

  it.each(["9007199254740992", "9007199254740993", "-9007199254740992", "9223372036854775807"])(
    "refuses integer %s before precision can be lost",
    (value) => expect(() => shapeParser.int8(value)).toThrow(RangeError),
  )

  it.each(["", "1.5", "1e3", "NaN", "Infinity", " 42", "42\n", "42\r\n"])(
    "rejects malformed wire integer %s",
    (value) => expect(() => shapeParser.int8(value)).toThrow(TypeError),
  )
})
