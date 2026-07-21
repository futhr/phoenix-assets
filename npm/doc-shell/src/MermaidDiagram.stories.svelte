<script module>import { defineMeta } from "@storybook/addon-svelte-csf"
import MermaidDiagram from "./MermaidDiagram.svelte"

const { Story } = defineMeta({
  title: "DocShell/MermaidDiagram",
  component: MermaidDiagram,
  tags: ["autodocs"],
})
</script><Story name="Default"><MermaidDiagram code="graph TD; A--&gt;B" /></Story>
