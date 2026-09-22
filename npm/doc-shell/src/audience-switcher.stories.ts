import type { Meta, StoryObj } from "@storybook/svelte-vite"
import AudienceSwitcher from "./audience-switcher.svelte"

const meta: Meta = { title: "DocShell/Audience switcher", component: AudienceSwitcher }
export default meta
type Story = StoryObj
export const Default: Story = { args: { audiences: ["developer", "operator"], value: "developer" } }
