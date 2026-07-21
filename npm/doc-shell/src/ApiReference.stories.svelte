<script module>import { defineMeta } from "@storybook/addon-svelte-csf"
import ApiReference from "./ApiReference.svelte"
import { spec } from "./fixtures.js"

const { Story } = defineMeta({
  title: "DocShell/ApiReference",
  component: ApiReference,
  tags: ["autodocs"],
})
</script><Story name="Default"><ApiReference {spec} /></Story>
