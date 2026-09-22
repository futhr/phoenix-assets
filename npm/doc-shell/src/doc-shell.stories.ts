import type { Meta, StoryObj } from "@storybook/svelte-vite"
import DocShell from "./doc-shell.svelte"
import { presentation } from "./fixtures.js"

const meta: Meta = {
  title: "DocShell/Legacy presentation",
  component: DocShell,
  parameters: { layout: "fullscreen" },
}
export default meta
type Story = StoryObj
export const StaticProjection: Story = {
  args: {
    presentation,
    currentId: "intro",
    currentPath: "/docs/intro",
    audiences: ["developer", "operator"],
    locales: ["en", "de"],
  },
}
