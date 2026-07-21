<script module>import { defineMeta } from "@storybook/addon-svelte-csf"
import LocaleSwitcher from "./LocaleSwitcher.svelte"

const { Story } = defineMeta({
  title: "DocShell/LocaleSwitcher",
  component: LocaleSwitcher,
  tags: ["autodocs"],
})
</script><Story name="Default"><LocaleSwitcher locales={["en", "de"]} value="en" /></Story>
