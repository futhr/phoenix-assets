import type { Meta, StoryObj } from "@storybook/svelte-vite"
import TableOfContents from "./table-of-contents.svelte"

const meta: Meta = { title: "DocShell/Table of contents", component: TableOfContents }
export default meta
type Story = StoryObj
export const Default: Story = { args: { items: [{ id: "start", level: 2, text: "Start" }] } }
