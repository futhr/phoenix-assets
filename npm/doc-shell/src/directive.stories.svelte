<script module>import { defineMeta } from "@storybook/addon-svelte-csf"
import Directive from "./directive.svelte"
import { directiveNames } from "./directives.js"

const { Story } = defineMeta({
  title: "DocShell/Directive",
  component: Directive,
  tags: ["autodocs"],
})
</script><Story name="All directives">{#each directiveNames as name}<Directive {name} title={name}>{#snippet children()}Content{/snippet}</Directive>{/each}</Story>
