# IS-R57 Lessons Learned

## 1. A new invariant found a defect the previous milestone's audit missed

I wrote I-78 to catch bare `ActivityRepository` constructions. On its first run
it failed on `IntentRepository` in `HomeScreen` — bare, and with no composition
owner either. R56's audit had not flagged it.

I composed it rather than narrowing the rule. Narrowing would have been the
"make it green" move this project has refused since R47.

**Carry forward:** write the invariant for the general property, not for the
instances you already know about, and treat its first-run failures as findings
rather than noise.

## 2. Distinguish a defaulted SEAM from a bare CONSTRUCTION

The literal reading of "no repository constructed outside approved locations"
would have banned `activity ?? ActivityRepository()` in six coordinators — an
API change this milestone forbids, breaking every test that relies on defaults,
for no gain, because the composition now passes its instance so the default
never fires.

The useful rule turned out to be about *shape*, not *place*: a construction
with an injection seam is fine; a bare one is not.

**Carry forward:** when a rule as stated would force a forbidden change, look
for the narrower property that captures the actual defect. Here it was the
difference between "can be substituted" and "cannot".

## 3. Ownership only became real when removing it broke the build

Mutation probe D deleted the composition registration. It did not merely fail
certification — **it failed to compile, in three places**, because consumers
now RECEIVE the instance instead of constructing their own.

That is the same signal R55 got when creation's repository field became unused
and was deleted: once ownership is genuine, the type system enforces it for
free.

**Carry forward:** a good ownership refactor makes the old shape
*uncompilable*, not merely *forbidden*. If removing the owner still compiles,
the consumers are not really consuming it.

## 4. I disproved my own hypothesis again, and kept the change anyway

`HomeScreen` built its own `SqliteExperienceRepository` while already holding
the composition. I believed this caused G-40's `database is locked` flakiness.

Measured: **3 failures / 11 runs with the fix; 3 / 11 without.** No improvement.

I kept the change — a screen holding the composition must not build its own
repository — and claimed nothing about G-40, which remains open and
unexplained.

**Carry forward:** two milestones running, measurement has contradicted a
plausible hypothesis (R56: activity was not losing writes; R57: this was not
G-40's cause). A change can be correct on architectural grounds and still fix
nothing measurable — say both.

## 5. Dead code hides in barrels, and it comes in pairs

Phase 4 named `MinimalKernel`. The audit found a second, larger case:
`lib/core/contracts/repository.dart` — four contracts, twenty methods, zero
implementations, reachable only through a barrel re-export, with a name
(`IntentRepository`) that **collided** with the live storage repository.

Identical in shape to the dead `runtime.dart` R47 deleted. The barrel still
carries R47's comment explaining that removal — sitting three lines above the
next instance of the same problem.

**Carry forward:** when you find one dead barrel export, scan every other
export in that barrel immediately. And a name collision between a dead contract
and a live implementation is a compile break waiting for the first file that
imports both.

## 6. Record the deliberate non-owners

`ExperienceDatabase` (per Experience) and `DurableCollectionStore` (stateless
`const` value) are NOT composed, on purpose. Composing them would mean a
factory abstraction with one implementation, or ceremony around a value object.

Both are recorded in the ownership matrix with the reason. An ownership matrix
where two rows are simply absent invites someone to "fix" them later.

**Carry forward:** a canonicalisation milestone must document what it
deliberately left uncanonical, or the next audit will re-litigate it.
