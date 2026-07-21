<script module>import { defineMeta } from "@storybook/addon-svelte-csf"
import CodeBlock from "./CodeBlock.svelte"

const { Story } = defineMeta({
  title: "DocShell/CodeBlock",
  component: CodeBlock,
  tags: ["autodocs"],
})
</script><Story name="Default"><CodeBlock code="const ok = true" language="typescript" /></Story>
