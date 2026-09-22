import type { Meta, StoryObj } from "@storybook/svelte-vite"
import MermaidDiagram from "./mermaid-diagram.svelte"

const meta: Meta = { title: "DocShell/Mermaid diagram", component: MermaidDiagram }
export default meta
type Story = StoryObj
export const Default: Story = { args: { code: "graph TD; A-->B" } }
