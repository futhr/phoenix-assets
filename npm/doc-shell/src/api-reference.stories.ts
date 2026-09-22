import type { Meta, StoryObj } from "@storybook/svelte-vite"
import ApiReference from "./api-reference.svelte"
import { spec } from "./fixtures.js"

const meta: Meta = { title: "DocShell/API reference", component: ApiReference }
export default meta
type Story = StoryObj
export const Default: Story = { args: { spec } }
