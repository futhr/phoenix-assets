import type { Meta, StoryObj } from "@storybook/svelte-vite"
import { siteFixture } from "./site-fixtures.js"
import SiteShell from "./site-shell.svelte"

const meta: Meta = {
  title: "DocShell/Portable site",
  component: SiteShell,
  parameters: { layout: "fullscreen" },
}
export default meta
type Story = StoryObj
export const Guide: Story = { args: { site: siteFixture, pageId: "guide" } }
export const NotFound: Story = { args: { site: siteFixture, pageId: "missing" } }
