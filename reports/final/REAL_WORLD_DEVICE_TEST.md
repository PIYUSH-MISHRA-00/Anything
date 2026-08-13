# REAL-WORLD DEVICE TEST — first-time-user certification

Device: moto g31 (ZD2225JSBY), Android 12. Build: release APK from
`v2.0.0` HEAD, then a debug APK for forensic DB inspection, then a
final release APK carrying the fixes. Every screen below was driven on
the physical device as a first-time user would: type intent → generate
→ use the generated app.

## What I did

Created three apps that had never been made in this environment before,
by typing plain intent into "What do you want?":

1. **"3D printer filament spool inventory and print job tracker"**
2. **"daily workout log with exercise, sets, reps and date"**
3. (regression) beekeeping tracker — a known records-shaped app

Then I acted as a real user: opened the generated app, tried to add a
record, picked a date, filled fields, tapped Create, and checked the
list — including after force-stop + restart.

## Findings

### 1. Create silently did not persist — ROOT-CAUSED & FIXED

**Symptom (real user):** In the generated "Workout Log", I filled the
Add form (date via native picker, exercise, sets, reps), tapped Create,
returned to the list — and it still said **"No items yet."** It stayed
empty after force-stop + restart. The record simply vanished.

**Forensic proof:** I built a debuggable APK and pulled the app's SQLite
via `run-as`. The experience's `records` table had **0 rows** — the
insert never ran. The DB file itself existed (the data runtime was
initialised), so this was not a storage-init failure.

I then pulled the stored package from `anything_experiences.db` and read
its behavior graph:

| | value |
|---|---|
| data entity id | `workout_log` |
| create event `eventId` | `add_workout` |
| create mutation entity | `workout_log` |

**Root cause:** the runtime resolves the renderer's generic
`submitForm(entityId: workout_log)` to a behavior event by
`eventId.contains(entityId)`. `'add_workout'.contains('workout_log')`
is **false** (the event noun "workout" ≠ the entity id "workout_log"),
so resolution failed, `execute()` returned early, and the insert node
was never reached. Beekeeping worked only because its event id and
entity id happened to be identical strings.

**Fix** (`lib/runtime/behavior_interpreter.dart`): resolve by the
event's downstream `dataMutation` entity binding — the authoritative
link between an event and its record entity — instead of fuzzy
substring-matching the event id's spelling. The old substring check is
kept as a fallback for graphs where the noun matches.

**Verified on device (release build with fix):** created "Leg Day" →
it **appears in the list immediately** and **survives force-stop +
restart.** Regression test `test/dynamic/p28_records_persistence_test.dart`
reproduces the exact `add_workout` vs `workout_log` divergence and
asserts the insert runs.

### 2. Date field showed its description, not the picked value — FIXED

**Symptom:** the read-only date field displayed the field label/hint
even after I picked a date in the native calendar.

**Root cause:** the date `TextFormField` used `initialValue` with no
controller, so a picked value could never re-render.

**Fix** (`lib/runtime/experience_renderer.dart`): a small stateful
`_DateField` owning a `TextEditingController`. **Verified on device:**
picking Aug 15 now shows `2026-08-15`, and the value survives editing
other fields.

### 3. Reasoner mis-parses a field list into separate entities — OPEN

"daily workout log **with exercise, sets, reps and date**" was parsed
into **five entities** (`daily_workout`, `exercise`, `sets`, `reps`,
`date`) instead of one entity with four fields. On device this produced
a five-tab app (Daily Workout / Exercise / Sets / Reps / Date lists)
with the four fields turned into reference dropdowns. It is usable (and
now persists, per fix #1) but is not the clean single-entity log a user
intended.

This is a **deterministic-reasoner limitation**, exposed because AI
generation is unavailable (see below). It is not a construction-factory
regression — no domain branch was added. Recommended follow-up: teach
the offline subject deriver that a trailing "with a, b, c and d" clause
enumerates *fields* of the primary entity, not new entities. Left
unfixed here because it is a reasoning-quality change that belongs with
the provider-restored AI path, not a runtime patch.

### 4. "Inventory / print job" mis-routed to a network shell — OPEN

The filament tracker generated an excellent name and description
("Manage and track 3D printer filament spool inventory and print jobs")
but the deterministic path routed it to the generic **network-reference
/ location-search** shell ("City or location" + Search + Refresh), not a
records model. There is no way to add a spool or a print job — unusable
for its stated purpose. Same class as the pottery-studio case in
`ARCHITECTURE_CERTIFICATION.md`: with no AI provider, the reasoner
guesses the interaction model from keywords and sometimes picks the
network shell for an "inventory/tracker" intent.

## AI generation status — unchanged

AI-driven generation remains **BLOCKED**: the configured Groq key returns
HTTP 401, so the composite reasoner runs the deterministic path for every
app above. Findings #3 and #4 are exactly the failure modes a working
model would resolve. Nothing here is classified as an AI PASS. No key was
placed in source, logs, screenshots, or this report; if the previously
supplied key was ever used it should be treated as compromised and
rotated (owner action).

## Follow-up mission: "train booking → generic search shell" (CRITICAL)

The reported vision defect — `Create a train ticket booking app` producing a
generic **"City or location" search shell** (search + refresh) instead of a
booking app — was **reproduced on device** and **root-caused via device
forensics**, then fixed generically (no domain factory).

**Forensics.** The offline/deterministic path already builds a correct records
app for train booking (host + a debug-build device pull both showed
`tags:[collection, best-effort]`, entity `train_ticket_booking`, List/Form/Edit,
`networkMode:none`). The failure came from an online path that inferred the
`networkData` capability, after which `creation_engine` **wholesale-replaced**
the records interface with `NetworkReferenceInterfaceFactory` — whose UI
hardcodes the weather-vestige label **"City or location"**.

**Three generic fixes** (commit `3883046`):
1. `creation_engine` — the user's own words decide the interaction model. A
   durable **collection/management** intent ("book", "manage", "tracker",
   "reservation", …) keeps its records UI and is never replaced by the
   reference search shell, even if planning produced a reference-shaped
   blueprint. Weather/news/lookup intents are unaffected.
2. `app_capabilities` — bare **"search"** is a records list operator, not a
   network signal (every records app has a search box); only genuine
   external-knowledge words infer `networkData`.
3. `experience_host_screen` — a generated `NavigationBar` with a single
   destination crashed the whole screen (Material asserts `>= 2`); guarded.

**Device-verified (release build):**
- `Create a train ticket booking app.` → a **booking records app** (Search /
  "No items yet" / Add Train Ticket Booking). Created & persisted a booking
  ("Delhi to Mumbai - Aug 20"). No search shell.
- `marine equipment rental management application …` (novel, blind) → a
  **multi-entity manager** with Equipment inventory / Customers / Reservations /
  Maintenance tracking tabs — through the same generic machinery, no marine
  factory, 4-tab nav renders without crash.
- Non-records domains (messaging, volunteer coordination) **honestly return
  "needs an AI model"** with the prompt preserved — never a wrong records/search
  substitute. This is correct degraded behaviour under the Groq-401 block, not a
  failure to install unrelated software.

Regression guards: `test/dynamic/p17_capability_resolution_test.dart` (booking +
"search" stays records), `test/dynamic/p29_open_world_routing_test.dart`
(novel record-shaped domain → multi-entity records; messaging → honest
provider-required).

## Verdict

- The critical "train booking → search shell" architecture defect is **fixed and
  device-verified**; booking/management/novel record-shaped domains now build
  the right app through generic machinery (no domain factory).
- Two real runtime defects found by first-time-user testing were
  **root-caused and fixed**, and the fixes are **verified end-to-end on
  the physical device** (create → persist → display → survive restart;
  date picker displays its value). Full suite: **2351 tests pass**,
  `flutter analyze` clean.
- Two **open reasoning-quality issues** (field-list-as-entities;
  inventory-intent mis-routing) are honestly documented as deterministic
  degradation, gated on AI provider restoration.
- **NOT PRODUCTION COMPLETE** overall: AI certification stays blocked by
  the invalid Groq key (owner action).
