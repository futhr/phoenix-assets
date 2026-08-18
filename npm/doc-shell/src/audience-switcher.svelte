<script lang="ts">interface Props {
  audiences: string[]
  value: string
  onchange?: (value: string) => void
}
const { audiences, value, onchange }: Props = $props()
</script>
<label>Audience <select {value} onchange={(event) => onchange?.(event.currentTarget.value)}>{#each audiences as audience}<option value={audience}>{audience}</option>{/each}</select></label>
<style>label { display: flex; gap: .5rem; align-items: center; font-size: .875rem; } select { border: 1px solid var(--doc-border); border-radius: var(--doc-radius); padding: .35rem; color: inherit; background: var(--doc-background); }</style>
