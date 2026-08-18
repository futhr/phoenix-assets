<script module>import { defineMeta } from "@storybook/addon-svelte-csf"
import Breadcrumbs from "./breadcrumbs.svelte"

const { Story } = defineMeta({
  title: "DocShell/Breadcrumbs",
  component: Breadcrumbs,
  tags: ["autodocs"],
})
</script><Story name="Default"><Breadcrumbs items={[{id: "docs", title: "Docs", path: "/docs"}]} /></Story>
