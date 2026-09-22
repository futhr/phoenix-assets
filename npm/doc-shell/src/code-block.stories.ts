import type { Meta, StoryObj } from "@storybook/svelte-vite"
import CodeBlock from "./code-block.svelte"

const meta: Meta = { title: "DocShell/Code block", component: CodeBlock }
export default meta
type Story = StoryObj
export const TypeScript: Story = { args: { code: "const ready = true", language: "typescript" } }
export const PlainText: Story = {
  args: { code: "unsupported language stays readable", language: "plain" },
}
