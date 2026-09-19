# Google Play — "Apply for access to production" answers

Copy-paste answers for the production access questionnaire (v2.0.0+3).
Every free-text field is capped at 300 characters; the counts below are exact.
**Edit anything that does not match what actually happened — Google cross-checks
these against your real closed-test data (opt-in dates, tester count, installs).**

---

## 1. About your closed test

### How did you recruit users for your closed test? (269/300)

> Entirely from my personal network - friends, family and colleagues. I approached each person individually, explained what the app does, and walked them through the opt-in link and the Play Store install. I did not use a paid testing provider or a tester-exchange group.

### How easy was it to recruit testers?

> **Difficult**

### Describe the engagement you received from testers (295/300)

> Testers used the core flow: describing an app in their own words, running the app Anything generated for them, and adding and editing data in it. Several also used 'Change this app' to modify one. The Discover web-data tab, export/import and app protection were used less than a real user would.

### Summary of feedback received, and how you collected it (299/300)

> Collected verbally in person and over WhatsApp/Discord, including screenshots testers sent me. They liked the speed and the concept. The two real issues were vague prompts failing to generate anything, and a crash after modifying an app. Both were reproduced on-device and fixed before this release.

**Verify before submitting:** the two issues named above are the ones fixed in
commits `caeb200`/`b9f8da7` (vague prompt -> "Could not plan this app") and the
"Change this app" red-screen crash. If your testers actually reported something
different, say what they reported instead.

---

## 2. About your app

Exact wording varies. Draft answers for the usual prompts:

### What does your app do / what is its core functionality?

> Anything turns a plain-language description into a real, working app on the
> user's own phone. You type what you need - "track my water intake", "a grocery
> list" - and the app designs, validates and runs a native experience for it. You
> can then change that app by describing the change. Everything runs on-device.

### Who is your app for / target audience?

> General adult users who want a small utility app without searching for one, plus
> makers and developers curious about on-device generative software. Not directed
> at children; the content rating and target-audience declaration are set to 18+.

### Is your app available elsewhere?

> Open source at github.com/PIYUSH-MISHRA-00/Anything (Apache-2.0). Not published
> on any other app store.

---

## 3. Your production readiness

### What changes did you make to your app based on what you learned during your closed test? (282/300)

> I fixed the two things testers hit: prompts the planner rejected now fall back to a working app instead of failing, and the crash after using 'Change this app' is gone. I also scoped modifications to the screen you are on, and fixed exported files not appearing in the file manager.

### How did you decide that your app is ready for production? (287/300)

> Every user-facing flow - creation, running, live web data, 'Change this app', protection and export/import - is verified end-to-end on a physical device. 2,357 automated tests pass in CI with the analyzer at zero issues, and no crash or blocking defect remains open from the closed test.

**Keep this consistent with your Section 1 feedback answer** - the two fixes
named here are the same two issues you said testers reported.

### If also asked: known issues / support plan

> No known crashes or blocking defects. The app needs the user to supply their own
> AI provider key before it can generate apps; this is by design (no account, no
> backend) and is explained on first run. Issues are tracked publicly on GitHub,
> support is dev@gratefulworldventures.in, and future versions go through the
> closed-testing track first.

---

## Blockers to clear BEFORE submitting

1. **Privacy policy URL must be publicly reachable.** `website/docs/privacy.md`
   exists, but the repo is private, so GitHub Pages returns 404. Play will
   reject a listing whose privacy policy URL does not load. Fix by making the
   repo public (re-enabling Pages) or hosting the policy anywhere public, then
   put that URL in Play Console -> Policy -> App content -> Privacy policy.

2. **App access instructions.** Anything is BYOK - a reviewer with no AI
   provider key cannot exercise the main feature. Fill Play Console -> App
   content -> **App access** with either a working test API key and the exact
   steps to enter it (Settings -> provider -> paste key), or a note explaining
   what the reviewer can see without one. Leaving this blank is a common
   rejection cause.

3. **Data safety form.** Declare: no data collected, no data shared, data stored
   on-device only. Microphone (`RECORD_AUDIO`) is used for voice input and the
   audio is not transmitted to the developer - say so. Note that prompts are sent
   to the user's chosen AI provider.

4. **Content rating questionnaire** and **Target audience & content** - both must
   be complete and consistent with the 18+ answer above.

## After access is granted

- Production -> Create new release -> upload the same signed AAB (or a newer
  build with a higher versionCode).
- Choose countries/regions, then a **staged rollout (start at 20%)** rather than
  100% - it lets you halt if crash-free rate drops.
- Watch Play Console -> Quality -> Android vitals for the first week.
