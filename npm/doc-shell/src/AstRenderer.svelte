<script lang="ts">
import AstRenderer from "./AstRenderer.svelte"
import { headingId, preCodeInfo } from "./ast.js"
import CodeBlock from "./CodeBlock.svelte"
import Directive from "./Directive.svelte"
import { isDirective } from "./directives.js"
import MermaidDiagram from "./MermaidDiagram.svelte"
import type { DocAstNode } from "./types.js"

interface Props {
  nodes: DocAstNode[] | string | null
}
const { nodes }: Props = $props()
const list = $derived(!nodes ? [] : typeof nodes === "string" ? [nodes] : nodes)
</script>

{#each list as node, index (index)}
  {#if typeof node === "string"}{node}
  {:else if isDirective(node.tag)}
    <Directive name={node.tag} title={node.attrs?.title}>{#snippet children()}<AstRenderer nodes={node.content ?? null} />{/snippet}</Directive>
  {:else if node.tag === "pre"}
    {@const info = preCodeInfo(node)}
    {#if info?.language === "mermaid"}<MermaidDiagram code={info.code} />{:else if info}<CodeBlock code={info.code} language={info.language} />{:else}<pre><AstRenderer nodes={node.content ?? null} /></pre>{/if}
  {:else if /^h[1-6]$/.test(node.tag)}
    <svelte:element this={node.tag as "h1"} id={headingId(node.content)}><AstRenderer nodes={node.content ?? null} /></svelte:element>
  {:else if ["p", "ul", "ol", "li", "blockquote", "strong", "em", "table", "thead", "tbody", "tr", "th", "td", "code"].includes(node.tag)}
    <svelte:element this={node.tag as "p"}><AstRenderer nodes={node.content ?? null} /></svelte:element>
  {:else if node.tag === "a"}<a href={node.attrs?.href}><AstRenderer nodes={node.content ?? null} /></a>
  {:else if node.tag === "br"}<br />{:else if node.tag === "hr"}<hr />
  {:else}<div data-unknown-tag={node.tag}><AstRenderer nodes={node.content ?? null} /></div>{/if}
{/each}

<style>
  :global(.doc-shell p) { line-height: 1.7; }
  :global(.doc-shell a) { color: var(--doc-accent); }
  :global(.doc-shell table) { width: 100%; border-collapse: collapse; }
  :global(.doc-shell th), :global(.doc-shell td) { border: 1px solid var(--doc-border); padding: .45rem; text-align: left; }
</style>
