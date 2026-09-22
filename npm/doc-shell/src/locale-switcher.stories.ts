import type { Meta, StoryObj } from "@storybook/svelte-vite"
import LocaleSwitcher from "./locale-switcher.svelte"

const meta: Meta = { title: "DocShell/Locale switcher", component: LocaleSwitcher }
export default meta
type Story = StoryObj
export const Default: Story = { args: { locales: ["en", "de"], value: "en" } }
