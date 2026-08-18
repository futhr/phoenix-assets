import { authHeaders, createShapeUrl } from "../electric/url.js"

/** HTTP methods a command may use. Reads belong on shapes, never here. */
export type CommandMethod = "POST" | "PUT" | "PATCH" | "DELETE"

/** Per-call overrides a generated command accepts. */
export interface CommandOptions {
  /** Replaces the global fetch (tests, SvelteKit `load`, instrumentation). */
  fetch?: typeof fetch
  /** Extra request headers, merged after the defaults. */
  headers?: Record<string, string>
  /** Abort signal for cancellation. */
  signal?: AbortSignal
}

export interface CommandRequest extends CommandOptions {
  path: string
  method: CommandMethod
  params?: Record<string, string | number>
  body?: unknown
}

/**
 * The outcome of a command.
 *
 * A failure is a value, not an exception: every call site has to handle both
 * arms to compile. `error` is one of the command's declared codes, or
 * `"unknown_error"` when the server answered with a code this build does not
 * know — so an unrecognised code degrades to a handled failure instead of
 * escaping as an untyped string.
 */
export type CommandResult<TData, TError extends string> =
  | { ok: true; data: TData }
  | { ok: false; error: TError | "unknown_error"; status: number }

/** The error code every command can return regardless of its declaration. */
export const UNKNOWN_COMMAND_ERROR = "unknown_error" as const

/**
 * Executes one generated command and normalises the outcome.
 *
 * Never throws and never rejects: a network failure, an unparseable body and an
 * undeclared error code all resolve to the failure arm. `knownErrors` is the
 * command's declared code list, and only a code in that list is passed through
 * with its own name.
 */
export async function runCommand<TData, TError extends string>(
  request: CommandRequest,
  knownErrors: readonly TError[] = [],
): Promise<CommandResult<TData, TError>> {
  try {
    const { path, method, params = {}, body, headers = {}, signal } = request
    const fetchFn = request.fetch ?? fetch
    const requestHeaders: Record<string, string> = {
      "Content-Type": "application/json",
      ...authHeaders(),
      ...headers,
    }

    const response = await fetchFn(createShapeUrl(path, params), {
      method,
      headers: requestHeaders,
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      ...(signal ? { signal } : {}),
    })
    const payload = await readJson(response)

    if (response.ok) return { ok: true, data: payload as TData }

    return {
      ok: false,
      error: errorCode(payload, knownErrors),
      status: response.status,
    }
  } catch {
    return { ok: false, error: UNKNOWN_COMMAND_ERROR, status: 0 }
  }
}

/** Reads a JSON body, tolerating an empty one (204, or a bodiless error). */
async function readJson(response: Response): Promise<unknown> {
  if (response.status === 204) return null

  try {
    return await response.json()
  } catch {
    return null
  }
}

/** Narrows the server's `error` field to a declared code, or `unknown_error`. */
function errorCode<TError extends string>(
  payload: unknown,
  knownErrors: readonly TError[],
): TError | typeof UNKNOWN_COMMAND_ERROR {
  if (typeof payload !== "object" || payload === null || !("error" in payload)) {
    return UNKNOWN_COMMAND_ERROR
  }

  const code = (payload as { error: unknown }).error

  return typeof code === "string" && (knownErrors as readonly string[]).includes(code)
    ? (code as TError)
    : UNKNOWN_COMMAND_ERROR
}
