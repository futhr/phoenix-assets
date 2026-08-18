<script module>import { defineMeta } from "@storybook/addon-svelte-csf"
import DocShell from "./doc-shell.svelte"
import { presentation } from "./fixtures.js"

const { Story } = defineMeta({ title: "DocShell/Shell", component: DocShell, tags: ["autodocs"] })
</script><Story name="Static or graph projection"><DocShell {presentation} currentId="intro" currentPath="/docs/intro" audiences={["developer", "admin"]} locales={["en", "de"]} /></Story>
