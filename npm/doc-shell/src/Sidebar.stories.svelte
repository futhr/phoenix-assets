<script module>import { defineMeta } from "@storybook/addon-svelte-csf"
import { presentation } from "./fixtures.js"
import Sidebar from "./Sidebar.svelte"

const { Story } = defineMeta({ title: "DocShell/Sidebar", component: Sidebar, tags: ["autodocs"] })
</script><Story name="Default"><Sidebar items={presentation.navigation} currentPath="/docs/intro" /></Story>
