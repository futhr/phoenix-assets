/** Where to read the auth token from, for shape requests. */
export interface AuthConfig {
  /** localStorage key holding the bearer token (default "auth_token"). */
  localStorageKey?: string
  /** Cookie name to fall back to when localStorage has no token. */
  cookieName?: string
  /**
   * Reads the token from somewhere else entirely — a `<meta>` tag, an injected
   * config object, a cookie the app already parsed. Tried before localStorage
   * and the cookie fallback; return `undefined` to fall through to them.
   */
  readToken?: () => string | undefined
  /**
   * Headers to merge into every shape request, on top of `Authorization`.
   *
   * A bearer token is not the only thing a Phoenix app has to send: CSRF tokens
   * and tenant selectors are just as common, and without a seam here an app has
   * to rebuild the whole header path to add one. Called per request, so a
   * rotating token stays current.
   */
  headers?: () => Record<string, string> | undefined
}

const DEFAULT_STORAGE_KEY = "auth_token"

let defaultAuthConfig: AuthConfig = {}

/**
 * Sets the process-wide default token source for shape requests.
 *
 * Generated `$phoenix/electric` clients call `authHeaders()` with no argument,
 * so an app whose token key isn't the default `"auth_token"` configures it once
 * at boot:
 *
 * ```ts
 * configureShapeAuth({
 *   localStorageKey: "my_app_token",
 *   headers: () => ({ "X-CSRF-Token": csrfToken() }),
 * })
 * ```
 */
export function configureShapeAuth(config: AuthConfig): void {
  defaultAuthConfig = { ...defaultAuthConfig, ...config }
}

/** Restores the default token source. Intended for tests. */
export function resetShapeAuth(): void {
  defaultAuthConfig = {}
}

/** Escapes regex metacharacters so a cookie name is matched literally. */
function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
}

/** Reads the auth token: `readToken`, then localStorage, then a cookie. */
export function getAuthToken(config: AuthConfig = {}): string | undefined {
  const merged = { ...defaultAuthConfig, ...config }
  const storageKey = merged.localStorageKey ?? DEFAULT_STORAGE_KEY

  if (merged.readToken) {
    const token = merged.readToken()
    if (token) return token
  }

  if (typeof localStorage !== "undefined") {
    try {
      const token = localStorage.getItem(storageKey)
      if (token) return token
    } catch {
      // Storage can be disabled by the browser or blocked in a sandboxed frame.
    }
  }

  if (merged.cookieName && typeof document !== "undefined") {
    const match = document.cookie.match(
      new RegExp(`(?:^|; )${escapeRegExp(merged.cookieName)}=([^;]*)`),
    )
    if (match?.[1]) {
      try {
        return decodeURIComponent(match[1])
      } catch {
        return match[1]
      }
    }
  }

  return undefined
}

/**
 * Builds the headers for a shape request, or `undefined` when there are none.
 *
 * `Authorization` when a token is available, merged with whatever `headers`
 * contributes. Explicit config wins over the process-wide default.
 */
export function authHeaders(config: AuthConfig = {}): Record<string, string> | undefined {
  const merged = { ...defaultAuthConfig, ...config }
  const token = getAuthToken(config)

  const headers: Record<string, string> = {
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...(merged.headers?.() ?? {}),
  }

  return Object.keys(headers).length > 0 ? headers : undefined
}

/**
 * Builds a shape URL: substitutes `:param` placeholders (URL-encoded) and appends
 * any remaining params as a query string.
 */
export function createShapeUrl(path: string, params: Record<string, string | number> = {}): string {
  const used = new Set<string>()

  const url = path.replace(/:([A-Za-z_][A-Za-z0-9_]*)/g, (_match, key: string) => {
    used.add(key)
    const value = params[key]
    if (value === undefined) {
      throw new Error(`createShapeUrl: missing path param ":${key}" for "${path}"`)
    }
    return encodeURIComponent(String(value))
  })

  const query = Object.entries(params).filter(([key]) => !used.has(key))
  if (query.length === 0) return url

  const search = new URLSearchParams(query.map(([key, value]) => [key, String(value)])).toString()
  return `${url}${url.includes("?") ? "&" : "?"}${search}`
}
