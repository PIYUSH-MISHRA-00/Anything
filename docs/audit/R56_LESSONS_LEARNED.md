# IS-R56 Lessons Learned

Written for the next milestone, not for the record. Each entry is something
that changed how I worked, with the evidence that produced it.

## 1. Measure the defect before designing the fix — it may disprove you

I entered R56 confident that all three SharedPreferences collections were
losing concurrent writes. A probe written **before any implementation**
returned:

```
ACTIVITY:      recorded 10 concurrently, stored 10        <- NOT lost
SCHEDULE:      scheduled 10 concurrently, pending  1      <- NINE LOST
NOTIFICATIONS: 1 scheduled,  presented 2 time(s)          <- exactly-once broken
```

Half my hypothesis was wrong. Had I skipped the probe, R56's documents would
today claim three fixed data-loss bugs, two of which never existed. The
architecture would be identical; the **claims** would be false.

**Carry forward:** for any defect-driven milestone, write the failing probe
first and let it size the claim. A fix you cannot demonstrate is a fix you
cannot honestly describe.

## 2. An ordering assertion is not a containment assertion

I-77 was meant to enforce "presentation happens after the claim". First form:

```dart
expect(presentIndex, greaterThan(body.lastIndexOf('store.update')));
```

The mutation probe moved presentation *inside* the mutation callback — the
exact defect — and the test **passed**, because the callback's text begins
after `store.update(` starts.

The property was never really about order. It was about **scope**: presentation
must not run *inside* the critical section. Rewritten using
balanced-parenthesis call ranges, it failed the probe correctly.

**Carry forward:** whenever an invariant says "X must happen after Y", ask
whether it actually means "X must not happen **inside** Y". Text position is a
poor proxy for scope, and a nested call is textually "after" its own opening
parenthesis.

## 3. Mutation testing found the bug in the *new* invariant, not the old code

Eleven milestones of mutation testing have mostly confirmed that new invariants
work. This is the first time a probe exposed a brand-new invariant as a **false
negative** — green and checking nothing — which is precisely the category
R48 discovered in the scanner and Phase 4 asks to hunt for.

**Carry forward:** the probe is not a formality after the invariant is written.
It is the only thing that distinguishes an invariant from a comment.

## 4. The heavier design was CAUSING the problem it was built to solve

R56's first implementation serialised callers through a static per-key future
chain with an async mutation callback. It deadlocked: `flutter_test` disposes a
zone between tests, and a chain entry left by one test was awaited forever by
the next. The full suite went from 2 minutes to 12, with eleven failures, and a
single 14-test file ran past ten minutes.

The fix was not a better lock. It was noticing that **the lock existed only to
survive a yield that the async callback reintroduced.** Making the mutation
callback synchronous removed the yield, which removed the need for the lock,
which removed the static state, the cross-zone futures and the deadlock
together.

The replacement is enforced by the type system — an async mutation does not
compile — which is stronger than the lock ever was.

**Carry forward:** when a synchronisation primitive is needed, ask what
introduced the interleaving before adding machinery to tolerate it. Removing a
yield point beats guarding one. And static mutable state that outlives a test
zone is a trap in any Flutter codebase.

## 5. Consolidation surfaces bugs that have nothing to do with the consolidation

`IntentRepository.updateStatus` and `.delete` read through `list()` (default
limit **50**) and wrote the result back as the whole history, while retention
allows 100 — silently discarding up to 30 records on any status update.

Nothing to do with concurrency. It became visible only because routing every
read and write of that key through one place put them side by side.

**Carry forward:** budget for incidental findings when consolidating a pattern.
They are a benefit of the work, not a distraction from it.

## 6. The compiler is a stronger guard than certification, when you can get it

R55's probe proved creation *cannot* write because its repository field was
deleted. R56's first probe likewise **would not compile** — until one word
(`async`) was added.

Both times the type system fired before certification. Both times, one line
silenced it.

**Carry forward:** prefer removing the *capability* to write over forbidding it;
but never treat a compile error as sufficient, because the fix a drifting
developer reaches for is exactly the one that re-enables the defect.

## 7. Record the clean results, not just the findings

The audit scanned ~15 duplication axes. Fourteen came back clean, mostly
because R46–R55 made them so. Writing those down is what distinguishes an audit
from a search for a predetermined answer — and it is the evidence that the
milestone's own title was wrong.

**Carry forward:** an audit report with only findings is indistinguishable from
confirmation bias.

## 8. A grep hit is not a fact

An early scan flagged `software_cognition/package_analyzer.dart` as persisting
outside `lib/storage/`. It was the string literal
`'shared_preferences': 'key-value storage'` in a package-name lookup table.

**Carry forward:** open the file before promoting a match to a finding, and
record corrected false positives so the audit's own reliability is visible.

## 9. Pin exclusions inside the test, with the reason

`ThemeProvider` writes `SharedPreferences` directly and is excluded from I-75 —
one scalar key, no read-modify-write, nothing to serialise. The exclusion and
its justification live *in the test*, and it is filed as G-39.

This is the fifth milestone applying the rule: **pin the real set with
rationale, never narrow the pattern until it passes.** Same for R55's
`touchLastUsed` (G-34) and R54's compatibility/dependency sibling sets.

## 10. Stage before probing — third milestone running

`git add` everything before the first mutation probe, so `git checkout --`
actually reverts. R53 lost time to this because the probe target was untracked
and the revert silently no-opped.

Now habitual, and it has cost nothing.

## 11. Operational: kill background test runs before re-running

A backgrounded `flutter test` held a lock on `build/native_assets/windows/
sqlite3.dll`, and the next run failed with a permissions error that looks
nothing like its cause. Stopping the stale task fixed it immediately.

**Carry forward:** on Windows, a confusing "cannot access the file" from the
Flutter tool usually means another run is still alive.

## 12. Stale test scratch is shared mutable state — and attribute flakiness with a CONTROLLED comparison

The repository had accumulated **24,699 test databases (1.8 GB)** under
`.dart_tool/sqflite_common_ffi/`, and every test using
`AppComposition.production()` shares one `anything_experiences.db`. Under
parallel file execution this produces intermittent `database is locked`
failures that move between test files run to run.

My first attribution attempt was **not a controlled experiment**: I ran one
file on the old commit and two files on the new one, saw a failure only on the
new one, and briefly concluded R56 had caused it. It had not.

The controlled version — same two files, same conditions, cleared database
directory, 11 runs each:

```
R56:  3 failures / 11
R55:  2 failures / 11        <- pre-existing, same failure mode
```

Indistinguishable, and the failure is a sqflite lock, which R56 does not touch.
Recorded as **G-40**, and it explains R50's G-24 (a non-reproducing failure
that was never diagnosed) as the same race.

**Carry forward:** flakiness attribution requires identical conditions on both
sides and enough runs to see a rate, not a single observation. And never let a
green/red pair from *different* commands become a conclusion.

## 13. `git checkout --` after a `stash pop` reverts to HEAD, not to your work

I ran a mutation probe, then reverted it with `git checkout -- <file>`. Between
staging and probing I had done a `git stash pop`, which left the file modified
but **unstaged** — so the checkout discarded every R56 change to that file, not
just the probe.

Nothing warned me. It surfaced two full-suite runs later as nine failures, and
the only reason it was caught quickly is that R56's own tests and invariants
failed loudly and specifically: "every durable COLLECTION mutates through the
ONE store", "TEN CONCURRENT schedule() CALLS ALL SURVIVE".

**Carry forward:** the "stage before probing" rule is not enough on its own —
any `stash` cycle in between silently invalidates it. Re-`git add` after
stashing, or revert probes by reversing the edit rather than by checkout. And
note the happy ending: **the certification layer caught my own destructive
mistake**, which is exactly what it exists for.
