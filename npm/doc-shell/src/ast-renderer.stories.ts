import type { Meta, StoryObj } from "@storybook/svelte-vite"
import AstRenderer from "./ast-renderer.svelte"

const meta: Meta = { title: "DocShell/AST renderer", component: AstRenderer }
export default meta
type Story = StoryObj
export const DirectivesAndCode: Story = {
  args: {
    nodes: [
      { tag: "callout", content: ["Hello"] },
      {
        tag: "pre",
        content: [
          { tag: "code", attrs: { class: "language-typescript" }, content: ["const ok = true"] },
        ],
      },
    ],
  },
}
