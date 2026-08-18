<script module>import { defineMeta } from "@storybook/addon-svelte-csf"
import AudienceSwitcher from "./audience-switcher.svelte"

const { Story } = defineMeta({
  title: "DocShell/AudienceSwitcher",
  component: AudienceSwitcher,
  tags: ["autodocs"],
})
</script><Story name="Default"><AudienceSwitcher audiences={["developer", "admin"]} value="developer" /></Story>
