import type { DocAstElement, DocAstNode } from "./types.js"

export const extractText = (content?: DocAstNode[] | string): string =>
  !content
    ? ""
    : typeof content === "string"
      ? content
      : content
          .map((node) => (typeof node === "string" ? node : extractText(node.content)))
          .join("")

export const headingId = (content?: DocAstNode[] | string): string =>
  extractText(content)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")

export const preCodeInfo = (
  node: DocAstElement,
): { code: string; language: string } | undefined => {
  if (!Array.isArray(node.content)) return undefined
  const code = node.content.find(
    (child): child is DocAstElement => typeof child !== "string" && child.tag === "code",
  )
  if (!code) return undefined
  return {
    code: typeof code.content === "string" ? code.content : extractText(code.content),
    language:
      code.attrs?.class?.replace(/^language-/, "") ??
      (node.attrs?.class === "mermaid" ? "mermaid" : "text"),
  }
}

export const extractToc = (
  nodes: DocAstNode[],
): Array<{ id: string; level: number; text: string }> => {
  const result: Array<{ id: string; level: number; text: string }> = []
  const visit = (items: DocAstNode[]) => {
    for (const item of items) {
      if (typeof item === "string") continue
      if (/^h[2-6]$/.test(item.tag))
        result.push({
          id: headingId(item.content),
          level: Number(item.tag[1]),
          text: extractText(item.content),
        })
      if (Array.isArray(item.content)) visit(item.content)
    }
  }
  visit(nodes)
  return result
}
