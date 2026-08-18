<script module>import { defineMeta } from "@storybook/addon-svelte-csf"
import { operation } from "./fixtures.js"
import OperationCard from "./operation-card.svelte"

const { Story } = defineMeta({
  title: "DocShell/OperationCard",
  component: OperationCard,
  tags: ["autodocs"],
})
</script><Story name="Default"><OperationCard entry={operation} /></Story>
