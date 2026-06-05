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

  const exact = supported.find((locale) => locale === requested)
  if (exact) return exact

  const base = requested.split("-")[0]
  return supported.find((locale) => locale === base) ?? fallback
}
