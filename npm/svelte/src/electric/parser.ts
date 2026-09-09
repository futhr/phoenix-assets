import type { ShapeStreamOptions } from "@electric-sql/client"

/**
 * Decode PostgreSQL integers as the numbers declared by generated Ash row types.
 * Values beyond JavaScript's exact integer range fail instead of silently rounding.
 * Electric supplies its normal parsers for other types, arrays, and null values.
 */
export const shapeParser = {
  int8: (value: string): number => {
    if (!/^-?\d+$/.test(value) || value.trim() !== value) {
      throw new TypeError("Invalid PostgreSQL int8 value")
    }
    const parsed = Number(value)
    if (!Number.isSafeInteger(parsed)) {
      throw new RangeError("PostgreSQL int8 is outside the safe JavaScript integer range")
    }
    return parsed
  },
} satisfies NonNullable<ShapeStreamOptions["parser"]>
