---
name: unslop
description: Cut AI tells from Phoenix Assets prose while preserving package names, technical contracts, commands, version numbers, and measured results. Use for README files, guides, audits, release notes, module docs, comments, and commit text.
---

# Unslop Phoenix Assets prose

Write like an experienced library maintainer. Keep the subject concrete, prefer
plain verbs, and remove sentences that only advertise confidence.

Avoid these common tells: delve, crucial, pivotal, testament, tapestry,
landscape, interplay, intricate, vibrant, underscore, enduring, additionally,
leverage, robust, seamless, comprehensive, holistic, foster, empower, journey,
elevate, and supercharge.

Replace inflated constructions with direct prose:

- "serves as", "stands as", and "acts as" become "is";
- remove "not just X, but Y", forced triads, empty gerund endings, stacked
  hedges, vague authority, and throat-clearing introductions;
- remove filler such as "in order to" and "the fact that";
- use bold only as a useful scan anchor;
- avoid decorative emoji and chains of em dashes.

Preserve code, commands, identifiers, paths, release versions, dependency
constraints, checksum or coverage values, and public contract wording exactly.
Do not soften failure behavior or widen compatibility claims. Keep Phoenix,
Elixir, OTP, Vite, SvelteKit, Storybook, Tailwind, Electric, Ash, Hex, npm, and
package names exact.

For product and technical claims, also apply the local
`phoenix-assets-evidence-voice` skill.

Before finishing, reread the result once and remove anything that still sounds
machine-written.
