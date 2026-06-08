/** Where to read the auth token from, for shape requests. */
export interface AuthConfig {
  /** localStorage key holding the bearer token (default "auth_token"). */
  localStorageKey?: string
  /** Cookie name to fall back to when localStorage has no token. */
  cookieName?: string
}

const DEFAULT_STORAGE_KEY = "auth_token"

let defaultAuthConfig: AuthConfig = {}

/**
 * Sets the process-wide default token source for shape requests.
 *
 * Generated `$phoenix/electric` clients call `authHeaders()` with no argument,
 * so an app whose token key isn't the default `"auth_token"` configures it once
 * at boot (e.g. `configureShapeAuth({ localStorageKey: "my_app_token" })`).
 */
export function configureShapeAuth(config: AuthConfig): void {
  defaultAuthConfig = { ...defaultAuthConfig, ...config }
}

/** Escapes regex metacharacters so a cookie name is matched literally. */
function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
}

/** Reads the auth token from localStorage, then (optionally) a cookie. */
export function getAuthToken(config: AuthConfig = {}): string | undefined {
  const merged = { ...defaultAuthConfig, ...config }
  const storageKey = merged.localStorageKey ?? DEFAULT_STORAGE_KEY

  if (typeof localStorage !== "undefined") {
    const token = localStorage.getItem(storageKey)
    if (token) return token
  }

  if (merged.cookieName && typeof document !== "undefined") {
    const match = document.cookie.match(
      new RegExp(`(?:^|; )${escapeRegExp(merged.cookieName)}=([^;]*)`),
    )
    if (match?.[1]) return decodeURIComponent(match[1])
  }

  return undefined
}

/** Builds the `Authorization` header map, or `undefined` when there is no token. */
export function authHeaders(config: AuthConfig = {}): Record<string, string> | undefined {
  const token = getAuthToken(config)
  return token ? { Authorization: `Bearer ${token}` } : undefined
}

/**
 * Builds a shape URL: substitutes `:param` placeholders (URL-encoded) and appends
 * any remaining params as a query string.
 */
export function createShapeUrl(path: string, params: Record<string, string | number> = {}): string {
  const used = new Set<string>()

  const url = path.replace(/:([A-Za-z_][A-Za-z0-9_]*)/g, (_match, key: string) => {
    used.add(key)
    return encodeURIComponent(String(params[key] ?? ""))
  })

  const query = Object.entries(params).filter(([key]) => !used.has(key))
  if (query.length === 0) return url

  const search = new URLSearchParams(query.map(([key, value]) => [key, String(value)])).toString()
  return `${url}${url.includes("?") ? "&" : "?"}${search}`
}
