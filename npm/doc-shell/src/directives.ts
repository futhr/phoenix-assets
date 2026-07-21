export const directiveNames = [
  "accordion",
  "badge",
  "callout",
  "card",
  "card-grid",
  "code-group",
  "frame",
  "response-fields",
  "snippet",
  "step",
  "steps",
  "tabs",
  "tree",
  "update",
] as const

export type DirectiveName = (typeof directiveNames)[number]
export const isDirective = (name: string): name is DirectiveName =>
  directiveNames.includes(name as DirectiveName)
