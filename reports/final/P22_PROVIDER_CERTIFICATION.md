# P22 — Provider (Groq 401) root cause + AI-required policy

HEAD after `openai_compatible_provider` trim fix. Reproduced from source; the
Groq credential itself was never inspected, scraped, or logged.

## 1. The Groq 401 — root cause FOUND and FIXED

Owner report: the Groq key is independently verified to work, yet Anything fails
generation with HTTP 401.

**Cause (in Anything, not the credential):** an asymmetry between how the key is
*validated* and how it is *stored/used*, in `lib/ai/openai_compatible_provider.dart`.

| Path | Code | Behaviour |
|---|---|---|
| Validate | `testConnection(apiKey)` line 153 | `apiKey.trim()` → validates the **trimmed** key via `GET /models` → **reports success** |
| Save | `saveApiKey(apiKey)` line 546 (before) | stored the key **raw** |
| Read | `_readStoredKey()` line 131 (before) | returned the key **raw** |
| Use | `_headers()` line 137 | builds `'Authorization': 'Bearer $apiKey'` |

A key pasted with a trailing newline/space (the common case on Android paste)
therefore **passes the Test button** (which trims) but generation sends
`Authorization: Bearer <key>\n` — a corrupted header Groq answers with **401**.
The credential is valid; the request was malformed. This exactly matches
"the key works but the app says it's invalid."

**Fix:** normalise (trim) the key at both cache boundaries —
`saveApiKey` and `_readStoredKey`. Reading also repairs an **already-stored**
key on the next launch, so the owner needs no re-entry. Regression test
`test/p07_ai_runtime_integration_test.dart` → *"a pasted key is trimmed so
generation does not 401"* asserts the on-wire `Authorization` header is
`Bearer <key>` with no trailing whitespace after saving `"...\n "`.

**Verification the owner must do (I cannot):** I cannot read or re-enter the
owner's key (no scraping), and I cannot apply this Dart change to the *existing
release install* without either reinstalling — which clears the credential vault
(different signing key) — or a `flutter run` hot-reload session. So the owner
verifies by either (a) `flutter run` hot-restart against the dev machine
(preserves the vault, applies the fix, re-test generation), or (b) rebuild +
reinstall + re-enter the key once. On next launch the stored key is trimmed and
generation should no longer 401. If a 401 persists after this, it is a *second*
cause (stale registry, wrong model, endpoint) and needs the sanitized
request-time fingerprint diagnostic (see §3).

## 2. The AI-required policy — ANALYSIS, not yet enforced (by design)

Owner mandate: an application-generation request ("train ticket booking",
"messaging", "weather", "marine rental", …) must **require AI**; the deterministic
CRUD/best-effort path must not silently substitute when AI is unavailable.
Trivial local computation (calculator, stopwatch, timer) and system operations
may remain deterministic.

Current behaviour (`lib/synthesis/composite_reasoner.dart`): when no provider is
configured (or the model fails), `tryBestEffortPrimaryEntity` fabricates a
single/multi-entity records app (the `best-effort` / `managed-records` tags).
That is precisely the "silent substitution" the owner is banning for
app-generation.

**Why this is NOT flipped in the same commit as the 401 fix:** removing the
deterministic fallback while AI is still returning 401 would leave
app-generation with **nothing** — a bricked create flow — and I cannot verify
the 401 fix against the owner's real key from here. The owner's own phase order
(Part 51: fix provider → verify AI works → then test no-key behaviour) is the
safe sequence. Blast radius is also real: 16 test files encode the current
deterministic-creation contract and must be migrated to the new honest policy
(app-generation without AI → `ProviderRequired`, prompt preserved, Settings +
Retry), not weakened.

**Recommended next step (once the owner confirms AI generates with their key):**
gate `tryBestEffortPrimaryEntity` (and the managed-records/collection deterministic
app-generation paths) behind "no working provider ⇒ `ReasoningProviderRequired`",
keeping only the calc/timer capability shells deterministic. Then migrate the 16
affected tests to assert the honest failure. This is a focused, mechanical change
once AI is confirmed working — but doing it blind would be reckless.

## 2b. Booking → search shell on the WORKING-KEY path — FIXED

The earlier train→records fix covered the no-key deterministic path. The owner
still saw the "City or location" search shell **with a working key** — a
different (model) path. Root-caused to two generic sites (commit `b9e87df`):

1. **`app_capabilities`**: a model may over-declare `networkData` on a booking
   app. That made `networkData` a REQUIRED capability, which cascades into
   required `refresh`/`resultDisplay` surfaces that only the reference search
   shell provides — so the records app was either replaced by the shell or
   failed validation. A records-PRIMARY app (entities + CRUD, or collection/
   tracker archetype) now treats external data as **optional** and drops the
   `networkData`/`webData` requirement.
2. **`deterministic_repair`**: the repair pass injected the search shell
   (wholesale interface replacement) on any networkData gap, clobbering a good
   model-built records app. It now **skips the shell whenever a records surface
   exists** (entity list/form); the shell is only for pure reference apps.

**Verified** by an end-to-end test (`test/p07_ai_runtime_integration_test.dart`
→ "a booking app from the model is NOT turned into a search shell"): a scripted
model returning a booking app *with* networkData now yields a records app, not
the `reference_main` shell. Weather/news (reference-primary) still get the shell.
Deterministic path re-confirmed on device (moto g31, release): "professional
train ticket booking application" → records booking app, no shell, no crash.

## 2c. End-to-end AI generation — VERIFIED on device with a real key

With the owner's Groq key on a diagnostic debug build, the full path was
verified on the device (moto g31), logs + screenshots:

- **AI runs and succeeds**: `keyLen=56`, both/all Groq calls complete
  (understanding + architecture, ~2300–3000 tokens each). No 401. The trim fix
  resolved it — the key was valid, the request was corrupted by trailing
  whitespace.
- **Real relational full-stack app**: "Train Ticket Booking App" with
  Booking + Train + Route/User/Schedule entities and reference fields — genuine
  AI software generation, not a search shell or generic CRUD.
- **Completeness fix** (commit trail): every entity now has a navigable list
  tab + Add (Train List "Add train" confirmed) — referenced entities are no
  longer dead ends.
- **Create + persist**: added a train (T-101 / Rajdhani Express) — it persisted
  and survived app regeneration (same experience DB).
- **Reference inference fix**: the booking's `train_id` dropdown — previously
  empty because the model left `referenceEntityId` null — now **populates with
  the persisted train and is selectable**. A booking's references can be filled.

`adb install -r` (debug builds share a signing key) preserves the vault, so
iterating no longer wipes the key.

## Known remaining polish (non-blocking)
- Reference dropdown shows the record id (`rec-…`) instead of the entity's
  display field (e.g. "Rajdhani Express") — `getRecordLabel` not resolving the
  display field for these entities.
- A generated form field with a long description triggers a debug-only
  RenderFlex overflow (release clips it; no functional impact).
- "No app without an AI key" policy still not enforced (deterministic fallback
  still generates offline). Safe to enforce now that AI is confirmed working.

## 3. Honest blockers

- **AI generation still unverified end-to-end from here.** The 401 root cause is
  fixed with high confidence and a regression test, but proving a live Groq
  round-trip requires the owner's key on a build that has this fix — which only
  the owner can exercise without me scraping/destroying the credential.
- **AI-required policy not yet enforced** — sequenced after AI is confirmed, to
  avoid bricking generation (see §2).
- No secret entered source, logs, screenshots, reports, or Git.

## Verdict
- Groq 401: **root-caused and fixed** (trim asymmetry) with a regression test.
- AI-required policy: **understood and specified**, deliberately sequenced after
  the owner confirms AI works with their key — not enforced blind.
- **NOT production complete**: AI generation is unverified against a live key
  from this environment, and the no-silent-fallback policy is pending that
  confirmation.
