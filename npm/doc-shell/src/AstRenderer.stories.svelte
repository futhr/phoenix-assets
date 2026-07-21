<script module>import { defineMeta } from "@storybook/addon-svelte-csf"
import AstRenderer from "./AstRenderer.svelte"

const { Story } = defineMeta({
  title: "DocShell/AstRenderer",
  component: AstRenderer,
  tags: ["autodocs"],
})
</script><Story name="Directives and code"><AstRenderer nodes={[{tag: "callout", content: "Hello"}, {tag: "pre", content: [{tag: "code", attrs: {class: "language-ts"}, content: "const ok = true"}]}]} /></Story>
