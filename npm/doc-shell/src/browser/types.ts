export interface SearchRecord {
  id: string
  page_id: string
  route: string
  title: string
  section?: string | null
  text: string
  locale: string
  audience?: string | string[] | null
  kind: string
  collection: string
  version: string
  tags: string[]
  status?: string | null
}

export interface SearchFilters {
  collection?: string
  kind?: string
  locale?: string
  audience?: string | string[]
  version?: string
  tag?: string
  status?: string
}

export interface BrowserController {
  refresh: () => void
  destroy: () => void
}

export type ThemePreference = "system" | "light" | "dark" | "contrast"
