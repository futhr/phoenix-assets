<script lang="ts">
import JsonView from "./JsonView.svelte"
import type { OperationEntry } from "./types.js"

interface Props {
  entry: OperationEntry
  baseUrl?: string
  request?: typeof fetch
}
const { entry, baseUrl = "", request = fetch }: Props = $props()
let open = $state(false)
let token = $state("")
let body = $state("")
let loading = $state(false)
let status = $state<number>()
let response = $state<unknown>()
const hasBody = $derived(["POST", "PUT", "PATCH"].includes(entry.method))
const send = async () => {
  loading = true
  status = undefined
  response = undefined
  try {
    const headers: Record<string, string> = { "content-type": "application/json" }
    if (token) headers.authorization = token.startsWith("Bearer ") ? token : `Bearer ${token}`
    const result = await request(baseUrl + entry.path, {
      method: entry.method,
      headers,
      body: hasBody && body ? body : undefined,
      credentials: "include",
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
<section><button type="button" onclick={() => (open = !open)} aria-expanded={open}>{open ? "Hide" : "Try it"}</button>{#if open}<div class="form"><label>Bearer token <input bind:value={token} /></label>{#if hasBody}<label>JSON body <textarea bind:value={body}></textarea></label>{/if}<button type="button" onclick={send} disabled={loading}>{loading ? "Sending…" : "Send request"}</button>{#if status !== undefined}<strong>Status {status}</strong>{/if}{#if response !== undefined}<JsonView value={response} />{/if}</div>{/if}</section>
<style>section { margin-top: 1rem; } .form, label { display: grid; gap: .5rem; } .form { margin-top: .75rem; } input, textarea, button { border: 1px solid var(--doc-border); border-radius: var(--doc-radius); padding: .5rem; background: var(--doc-background); color: inherit; } textarea { min-height: 8rem; font-family: ui-monospace, monospace; }</style>
