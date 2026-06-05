/** A generated topic builder: takes its parameters and returns the topic string. */
export type TopicBuilder = (...args: Array<string | number>) => string

/**
 * Dispatches a typed PubSub event to its matching handler.
 *
 * Pair with the generated `PubSubEvent` union from `$phoenix/pubsub` for
 * exhaustive, type-checked handling:
 *
 *     matchEvent(event, {
 *       "device:updated": (e) => render(e.payload),
 *       "device:deleted": (e) => remove(e.payload.id),
 *     })
 */
export function matchEvent<E extends { type: string }>(
  event: E,
  handlers: Partial<{ [K in E["type"]]: (event: Extract<E, { type: K }>) => void }>,
): void {
  const handler = (handlers as Record<string, ((event: E) => void) | undefined>)[event.type]
  if (handler) handler(event)
}
