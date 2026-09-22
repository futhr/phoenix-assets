import type { Meta, StoryObj } from "@storybook/svelte-vite"
import Breadcrumbs from "./breadcrumbs.svelte"

const meta: Meta = { title: "DocShell/Breadcrumbs", component: Breadcrumbs }
export default meta
type Story = StoryObj
export const Default: Story = {
  args: { items: [{ id: "docs", title: "Documentation", path: "/docs/" }] },
}
