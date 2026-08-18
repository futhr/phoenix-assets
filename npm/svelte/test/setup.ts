import { Window } from "happy-dom"

// Newer Node releases expose an experimental `localStorage` accessor that returns
// `undefined` unless `--localstorage-file` is configured. Make the browser test
// environment authoritative so the suite does not depend on Node CLI flags.
Object.defineProperty(globalThis, "localStorage", {
  configurable: true,
  value: new Window().localStorage,
})
