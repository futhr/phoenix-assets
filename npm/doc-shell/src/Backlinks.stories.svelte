<script module>import { defineMeta } from "@storybook/addon-svelte-csf"
import Backlinks from "./Backlinks.svelte"

const { Story } = defineMeta({
  title: "DocShell/Backlinks",
  component: Backlinks,
  tags: ["autodocs"],
})
</script><Story name="Default"><Backlinks items={[{id: "api", title: "API", path: "/api"}]} /></Story>
