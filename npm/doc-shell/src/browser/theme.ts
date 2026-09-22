import type { BrowserController, ThemePreference } from "./types.js"

const storageKey = "phoenix-assets:doc-shell:theme"
const allowed = new Set<ThemePreference>(["system", "light", "dark", "contrast"])

export const readTheme = (storage: Pick<Storage, "getItem"> = localStorage): ThemePreference => {
  const value = storage.getItem(storageKey) as ThemePreference | null
  return value && allowed.has(value) ? value : "system"
}

export const applyTheme = (root: HTMLElement, preference: ThemePreference) => {
  root.dataset.paTheme = preference === "system" ? "" : preference
  root.dataset.docTheme = preference
}

export const mountTheme = (
  root: HTMLElement,
  storage: Pick<Storage, "getItem" | "setItem"> = localStorage,
): BrowserController => {
  const controller = new AbortController()
  const refresh = () => applyTheme(root, readTheme(storage))
  root.addEventListener(
    "click",
    (event) => {
      const button = (event.target as Element).closest<HTMLElement>("[data-doc-theme-value]")
      const value = button?.dataset.docThemeValue as ThemePreference | undefined
      if (!value || !allowed.has(value)) return
      storage.setItem(storageKey, value)
      applyTheme(root, value)
    },
    { signal: controller.signal },
  )
  refresh()
  return { refresh, destroy: () => controller.abort() }
}
