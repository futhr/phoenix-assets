<script module>import { defineMeta } from "@storybook/addon-svelte-csf"
import JsonView from "./JsonView.svelte"

const { Story } = defineMeta({
  title: "DocShell/JsonView",
  component: JsonView,
  tags: ["autodocs"],
})
</script><Story name="Default"><JsonView value={{users: [{id: 1, active: true}]}} /></Story>
