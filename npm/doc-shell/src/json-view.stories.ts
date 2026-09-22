import type { Meta, StoryObj } from "@storybook/svelte-vite"
import JsonView from "./json-view.svelte"

const meta: Meta = { title: "DocShell/JSON view", component: JsonView }
export default meta
type Story = StoryObj
export const Default: Story = { args: { value: { users: [{ id: 1, active: true }] } } }
