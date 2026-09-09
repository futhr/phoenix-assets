---
name: phoenix-assets-evidence-voice
description: Apply to Phoenix Assets README files, HexDocs, npm package docs, usage rules, audits, release notes, and summaries. Keep package ownership, host boundaries, compatibility, release state, and test evidence precise.
---

# Phoenix Assets evidence voice

Describe what the library does, who owns each boundary, and what has actually
been tested. Name the relevant package or module instead of referring vaguely to
"the stack" or "the system".

Keep these distinctions explicit:

- Elixir runtime behavior versus npm package behavior;
- development supervision versus production asset serving;
- generated metadata versus host-owned authorization and business logic;
- frontend client compatibility versus an application's PostgreSQL, Electric,
  and Phoenix.Sync deployment;
- local qualification, CI qualification, published registry artifacts, and
  operational use.

Claims about compatibility, security, performance, publication, or production
use need a named contract or evidence source. Preserve exact versions, immutable
source revisions, commands, test counts, coverage values, artifact identities,
and failure semantics. Do not turn an integration library into a hosted product,
and do not let one consumer's domain language enter the generic package docs.

Use short examples when they clarify installation or ownership. Avoid marketing
claims that do not help a maintainer decide whether the library fits their
application.
