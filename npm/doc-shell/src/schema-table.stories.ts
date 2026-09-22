import type { Meta, StoryObj } from "@storybook/svelte-vite"
import SchemaTable from "./schema-table.svelte"

const meta: Meta = { title: "DocShell/Schema table", component: SchemaTable }
export default meta
type Story = StoryObj
export const Recursive: Story = {
  args: {
    schema: {
      type: "object",
      properties: { user: { type: "object", properties: { id: { type: "integer", example: 1 } } } },
    },
  },
}
