import type { Meta, StoryObj } from "@storybook/svelte-vite"
import Backlinks from "./backlinks.svelte"

const meta: Meta = { title: "DocShell/Backlinks", component: Backlinks }
export default meta
type Story = StoryObj
export const Default: Story = {
  args: { items: [{ id: "api", title: "API reference", path: "/docs/api/" }] },
}
