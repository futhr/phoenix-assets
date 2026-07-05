/**
 * Negotiates a requested locale against the supported set.
 *
 * Returns an exact match, then a base-language match (`sv-SE` -> `sv`), then the
 * fallback. Pair with `locales`/`defaultLocale` from `$phoenix/localize`.
 */
export function resolveLocale<L extends string>(
  requested: string | null | undefined,
  supported: readonly L[],
  fallback: L,
): L {
  if (!requested) return fallback

  const normalized = requested.toLowerCase()
  const exact = supported.find((locale) => locale.toLowerCase() === normalized)
  if (exact) return exact

  const base = normalized.split(/[-_]/)[0]
  return supported.find((locale) => locale.toLowerCase() === base) ?? fallback
}
