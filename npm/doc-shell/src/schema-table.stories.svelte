<script module>import { defineMeta } from "@storybook/addon-svelte-csf"
import SchemaTable from "./schema-table.svelte"

const { Story } = defineMeta({
  title: "DocShell/SchemaTable",
  component: SchemaTable,
  tags: ["autodocs"],
})
</script><Story name="Recursive and examples"><SchemaTable schema={{type: "object", properties: {user: {type: "object", properties: {id: {type: "integer", example: 1}}}}}} /></Story>
