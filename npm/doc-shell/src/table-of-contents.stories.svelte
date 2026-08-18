<script module>import { defineMeta } from "@storybook/addon-svelte-csf"
import TableOfContents from "./table-of-contents.svelte"

const { Story } = defineMeta({
  title: "DocShell/TableOfContents",
  component: TableOfContents,
  tags: ["autodocs"],
})
</script><Story name="Default"><TableOfContents items={[{id: "start", level: 2, text: "Start"}]} /></Story>
