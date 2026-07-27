/**
 * Declarative event-handler modifiers.
 *
 * Every surface re-implements the same four behaviours around a handler —
 * delay it, rate-limit it, run it once, stop the event — usually inline and
 * usually slightly differently. These wrap a handler instead, so the behaviour
 * is named at the binding (`onclick={once(submit)}`) and the handler itself
 * stays a plain function that is trivial to unit test.
 *
 * They compose right-to-left: `stopPropagation(debounce(save, 300))` debounces
 * the save and stops the event on every call, not only the ones that run.
 */

/** A DOM event handler, as Svelte binds it. */
export type EventHandler<E extends Event = Event> = (event: E) => void

/** A handler with a `cancel()` for pending work; safe to call at teardown. */
export interface CancellableHandler<E extends Event = Event> {
  (event: E): void
  cancel: () => void
}

/**
 * Runs the handler only after `waitMs` of quiet — the trailing edge.
 *
 * Each call restarts the timer, so a burst produces exactly one invocation.
 * The event is not retained: only the event's current values would survive the
 * delay, so the handler receives the event it was called with last.
 */
export function debounce<E extends Event>(
  handler: EventHandler<E>,
  waitMs: number,
): CancellableHandler<E> {
  let timer: ReturnType<typeof setTimeout> | undefined

  const wrapped = (event: E): void => {
    if (timer !== undefined) clearTimeout(timer)
    timer = setTimeout(() => {
      timer = undefined
      handler(event)
    }, waitMs)
  }

  wrapped.cancel = (): void => {
    if (timer !== undefined) clearTimeout(timer)
    timer = undefined
  }

  return wrapped
}

/**
 * Runs the handler at most once per `intervalMs` — the leading edge.
 *
 * The first call runs immediately; calls inside the window are dropped rather
 * than queued, so a held key or a scroll burst cannot build a backlog.
 */
export function throttle<E extends Event>(
  handler: EventHandler<E>,
  intervalMs: number,
): CancellableHandler<E> {
  let last = Number.NEGATIVE_INFINITY

  const wrapped = (event: E): void => {
    const now = Date.now()
    if (now - last < intervalMs) return
    last = now
    handler(event)
  }

  wrapped.cancel = (): void => {
    last = Number.NEGATIVE_INFINITY
  }

  return wrapped
}

/** Runs the handler on the first event only; later events are ignored. */
export function once<E extends Event>(handler: EventHandler<E>): EventHandler<E> {
  let spent = false

  return (event: E): void => {
    if (spent) return
    spent = true
    handler(event)
  }
}

/** Stops propagation, then runs the handler. */
export function stopPropagation<E extends Event>(handler: EventHandler<E>): EventHandler<E> {
  return (event: E): void => {
    event.stopPropagation()
    handler(event)
  }
}

/** Prevents the default action, then runs the handler. */
export function preventDefault<E extends Event>(handler: EventHandler<E>): EventHandler<E> {
  return (event: E): void => {
    event.preventDefault()
    handler(event)
  }
}

/**
 * Runs the handler only when the event's target is the bound element itself.
 *
 * The self-check for a click that must ignore clicks bubbling from children —
 * an overlay that closes on its own backdrop but not on the dialog inside it.
 */
export function self<E extends Event>(handler: EventHandler<E>): EventHandler<E> {
  return (event: E): void => {
    if (event.target !== event.currentTarget) return
    handler(event)
  }
}
