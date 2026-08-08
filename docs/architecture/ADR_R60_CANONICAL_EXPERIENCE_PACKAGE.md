# ADR — IS-R60: Canonical Experience package codec

**Status:** Accepted · **Date:** 2026-08-08 · **Milestone:** IS-R60

## Decision 1 — Create neither a manifest nor a validator

Phases 2 and 6 asked for both. Both existed and were certified (I-60; I-59/I-65).
Creating them would have produced the second manifest and second validator the
same document forbids.

**Decision:** reuse. The codec embeds the canonical manifest via the existing
package model and delegates structural validation with a literal
`ExperiencePackageValidator.validate` call, which I-88 requires to be present.

This is the third time a specification has asked for something already canonical
(R53 manifest/verifier, R54 migration engine, R60 manifest/validator). The
pattern is now familiar enough to check first, every time.

## Decision 2 — Canonical JSON, not zip

**Rejected:** adding `archive`. R60 forbids new dependencies, and a container
format is not worth one.

**Decision:** canonical JSON with an explicit `formatVersion`, so a binary
encoding can replace it later without touching the manifest, the validator or
any caller. The cost — no compression — is recorded rather than hidden.

## Decision 3 — Sorted-key determinism, and lists left alone

**Decision:** every map is emitted with sorted keys, recursively; lists keep
their order.

Sorting lists would corrupt the Experience — element order is data. Sorting maps
removes the only source of nondeterminism that mattered. Without this, the
checksum is meaningless and a future signature would be worse.

## Decision 4 — Verify the checksum against the rebuilt package

**Rejected:** hashing the raw container text. It would catch corruption but be
sensitive to whitespace and key order, making the digest brittle.

**Decision:** rebuild the package, then hash it with the existing
`computeIntegrityHash`. This catches a payload edited in transit *even when the
edit leaves valid JSON behind* — the case a "is it parseable" check waves
through.

## Decision 5 — Reserve a signature block and verify nothing

**Decision:** carry `signature` and `extensions` verbatim, read them back
unchanged, verify neither.

Reserving them means adding signing later needs no format change. Verifying
nothing is the same position R52 and R53 took: a package earns no authority by
being well-formed, and treating a signature's presence as proof is exactly the
"assumed rather than computed" failure R52 removed.

## Decision 6 — The reader stops at a model

**Decision:** the reader returns a package and nothing else. It cannot install,
activate, compute trust, distribute, or touch a file.

Parsing something must not run it. This is the same boundary R53 drew for
import and R54 for install, applied one layer further out — and it is the layer
where untrusted bytes first enter the system, so it is the one that matters
most.

## Consequences

**Positive** — the format half of G-25 is closed; the distribution envelope
round-trips for the first time; determinism is proven, not asserted; two new
mutation-proven invariants.

**Negative / accepted** — no file I/O yet, so G-25 remains open; no
compression; no signature verification; no UI.
