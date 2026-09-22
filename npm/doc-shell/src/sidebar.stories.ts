import type { Meta, StoryObj } from "@storybook/svelte-vite"
import { presentation } from "./fixtures.js"
import Sidebar from "./sidebar.svelte"

const meta: Meta = { title: "DocShell/Sidebar", component: Sidebar }
export default meta
type Story = StoryObj
export const Default: Story = {
  args: { items: presentation.navigation, currentPath: "/docs/intro" },
}
