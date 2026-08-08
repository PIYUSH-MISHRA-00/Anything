# IS-R59 Lessons Learned

## 1. Import analysis and name analysis disagree, and the disagreement is the finding

Import closure said 16 files were dead. Checking every declared type by name
reduced it to 14. The two survivors — `layout.dart`, `semantic_entity.dart` —
are exactly the files whose type names **collide with live declarations**: 36
and 167 apparent references that no text search can attribute.

Neither method is sufficient alone. Import analysis misses name-based coupling;
name analysis cannot resolve collisions.

**Carry forward:** when two independent methods disagree about deletion, the
answer is "not proven", not "pick the one you like". Pin it and say why.

## 2. Deleting dead code exposes more dead code

Removing `splash_screen.dart` made `onboarding_screen.dart` dead — it had one
importer, and that importer was the file just deleted.

A batch deletion would have missed it. Phase 8's "delete one group, validate,
repeat" loop is what surfaced it, and re-running the classifier after each
group is what made it visible.

**Carry forward:** dead-code removal is iterative. Re-run the analysis after
every deletion, not once at the start.

## 3. Test references are the discriminator that prevents catastrophe

43 files are unreachable from `main()` **and covered by tests**. Classified by
reachability alone they would all have looked dead. Deleting them would have
removed 43 files' worth of asserted behaviour.

**Carry forward:** "unreachable from the entry point" and "dead" are different
claims. The gap between them is where the tests live.

## 4. Certify the absence of a thing, not just the presence

The most valuable clause in I-85 is that **no `ProviderScope` exists**.

Nothing is wrong today precisely *because* it is missing. Adding one would
revive ~50 unreviewed files at once. An invariant that asserts an absence is
what stops a one-line change from silently reactivating a parallel
architecture.

**Carry forward:** when a subsystem is inert only because one thing is missing,
certify that the thing is still missing.

## 5. The gate caught a regression in the work that built the next gate

IS-R58's analyze gate failed on IS-R59's own certification code — infos rose
43 → 44 from one unbraced `if` inside the I-86 implementation.

That is the gate working, and it worked in the place a gate is easiest to
rationalise away: my own change, in the same session, while I was busy proving
something else.

**Carry forward:** the value of a gate is measured on the days you would rather
it stayed quiet.

## 6. I committed before reading validation output — three times

On three occasions I ran the suite, saw the summary line, and committed in the
same command without checking the result first. Twice it was the known G-40
flake; once (the analyze gate) it was a **real regression I had introduced**.

The habit that caused it: chaining `test` and `commit` in one invocation to save
a round-trip.

**Carry forward:** never chain validation and commit. The round-trip is cheaper
than the correction.

## 7. G-40 is not gone — my own R58 reading was too confident

R58 measured 0 failures in 22 runs and I reported the flakiness as not currently
reproducible. It appeared twice during R59.

The honest statement is that it is **intermittent at a low rate**, not absent.
0/22 was consistent with a ~5-10% rate; I read it as closer to zero than the
evidence supported.

**Carry forward:** a run of zeroes bounds a rate, it does not prove absence.
State the bound, not the conclusion.

## 8. Reproducible tooling beats a written finding

The reachability numbers live in `tool/reachability.py` and
`tool/classify_reachability.py`, not only in a report. Anyone can re-run them;
I-86 re-derives the same closure inside certification.

A finding in prose decays the moment the code moves. A finding in a script
does not.
