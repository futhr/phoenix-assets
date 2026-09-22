import type { Meta, StoryObj } from "@storybook/svelte-vite"
import { presentation } from "./fixtures.js"
import Search from "./search.svelte"

const meta: Meta = { title: "DocShell/Search", component: Search }
export default meta
type Story = StoryObj
export const Default: Story = { args: { entries: presentation.search } }
