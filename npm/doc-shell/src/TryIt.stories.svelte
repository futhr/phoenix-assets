<script module>import { defineMeta } from "@storybook/addon-svelte-csf"
import { operation } from "./fixtures.js"
import TryIt from "./TryIt.svelte"

const { Story } = defineMeta({ title: "DocShell/TryIt", component: TryIt, tags: ["autodocs"] })
</script><Story name="Collapsed"><TryIt entry={operation} /></Story>
