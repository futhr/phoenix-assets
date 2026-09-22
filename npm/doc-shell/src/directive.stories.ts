import type { Meta, StoryObj } from "@storybook/svelte-vite"
import Directive from "./directive.svelte"

const meta: Meta = { title: "DocShell/Directive", component: Directive }
export default meta
type Story = StoryObj
export const Callout: Story = { args: { name: "callout", title: "Note" } }
export const Accordion: Story = { args: { name: "accordion", title: "Details" } }
