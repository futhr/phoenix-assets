<script module>import { defineMeta } from "@storybook/addon-svelte-csf"
import { presentation } from "./fixtures.js"
import Search from "./search.svelte"

const { Story } = defineMeta({ title: "DocShell/Search", component: Search, tags: ["autodocs"] })
</script><Story name="Fuse search"><Search entries={presentation.search} /></Story>
