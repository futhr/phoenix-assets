<script lang="ts">
import JsonView from "./JsonView.svelte"
import type { OperationEntry } from "./types.js"
import { isAllowedTryItOrigin, resolveTryItTarget } from "./url.js"

interface Props {
  entry: OperationEntry
  baseUrl?: string
  allowedOrigins?: readonly string[]
  request?: typeof fetch
}
const { entry, baseUrl = "", allowedOrigins = [], request = fetch }: Props = $props()
let open = $state(false)
let token = $state("")
let body = $state("")
let loading = $state(false)
let status = $state<number>()
let response = $state<unknown>()
let confirmedOrigin = $state<string>()
let tokenOrigin = $state<string>()
const hasBody = $derived(["POST", "PUT", "PATCH"].includes(entry.method))
const resolution = $derived.by(() => {
  try {
    return { target: resolveTryItTarget(baseUrl, entry.path) } as const
  } catch (error) {
    return { error: error instanceof Error ? error.message : String(error) } as const
  }
})
const originAllowed = $derived(
  resolution.target
    ? !resolution.target.crossOrigin ||
        isAllowedTryItOrigin(resolution.target.origin, allowedOrigins)
    : false,
)
const originConfirmed = $derived(
  resolution.target
    ? !resolution.target.crossOrigin || confirmedOrigin === resolution.target.origin
    : false,
)
$effect(() => {
  const origin = resolution.target?.origin
  if (origin !== tokenOrigin) {
    token = ""
    confirmedOrigin = undefined
    tokenOrigin = origin
  }
})
const send = async () => {
  const target = resolution.target
  if (!target || !originAllowed || !originConfirmed) return

  loading = true
  status = undefined
  response = undefined
  try {
    const headers: Record<string, string> = { "content-type": "application/json" }
    if (token) headers.authorization = token.startsWith("Bearer ") ? token : `Bearer ${token}`
    const result = await request(target.url, {
      method: entry.method,
      headers,
      body: hasBody && body ? body : undefined,
      credentials: "same-origin",
    })
    status = result.status
    const text = await result.text()
    try {
      response = JSON.parse(text)
    } catch {
      response = text
    }
  } catch (error) {
    response = error instanceof Error ? error.message : String(error)
  } finally {
    loading = false
  }
}
</script>
<section><button type="button" onclick={() => (open = !open)} aria-expanded={open}>{open ? "Hide" : "Try it"}</button>{#if open}<div class="form">{#if resolution.error}<p role="alert">{resolution.error}</p>{:else if resolution.target?.crossOrigin}{#if originAllowed}<label class="origin-confirm"><input type="checkbox" checked={confirmedOrigin === resolution.target.origin} onchange={(event) => (confirmedOrigin = event.currentTarget.checked ? resolution.target?.origin : undefined)} /> Send this request to {resolution.target.origin}</label>{:else}<p role="alert">Requests to {resolution.target.origin} are blocked. Add the exact origin to <code>allowedOrigins</code> to enable confirmation.</p>{/if}{/if}<label>Bearer token <input bind:value={token} type="password" autocomplete="off" spellcheck="false" /></label>{#if hasBody}<label>JSON body <textarea bind:value={body}></textarea></label>{/if}<button type="button" onclick={send} disabled={loading || !resolution.target || !originAllowed || !originConfirmed}>{loading ? "Sending…" : "Send request"}</button>{#if status !== undefined}<strong>Status {status}</strong>{/if}{#if response !== undefined}<JsonView value={response} />{/if}</div>{/if}</section>
<style>section { margin-top: 1rem; } .form, label { display: grid; gap: .5rem; } .form { margin-top: .75rem; } input, textarea, button { border: 1px solid var(--doc-border); border-radius: var(--doc-radius); padding: .5rem; background: var(--doc-background); color: inherit; } textarea { min-height: 8rem; font-family: ui-monospace, monospace; }</style>
