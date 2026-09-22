import type { Meta, StoryObj } from "@storybook/svelte-vite"
import { operation } from "./fixtures.js"
import OperationCard from "./operation-card.svelte"

const meta: Meta = { title: "DocShell/Operation card", component: OperationCard }
export default meta
type Story = StoryObj
export const Default: Story = { args: { entry: operation } }
