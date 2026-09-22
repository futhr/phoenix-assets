import type { Meta, StoryObj } from "@storybook/svelte-vite"
import { operation } from "./fixtures.js"
import TryIt from "./try-it.svelte"

const meta: Meta = { title: "DocShell/Request panel", component: TryIt }
export default meta
type Story = StoryObj
export const DisabledByDefault: Story = { args: { entry: operation } }
