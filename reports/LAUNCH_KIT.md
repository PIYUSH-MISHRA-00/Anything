# Launch kit — Anything

Internal. `reports/` is this project's untracked scratch area, so nothing here
ships to a branch. Everything below is ready to paste.

**One thing must happen before any of it works: the repository has to be
public.** Topics are invisible on a private repo, every link in every post 404s
for anyone but you, and stars cannot be given. None of this is worth sending
until that switch is flipped.

Replace `SITE_URL` with the hosted docs URL once it exists.

---

## The one-liner

> Describe what you need and Anything builds, runs and keeps a real app for it
> — on your device, no account, no server.

Use it everywhere, unchanged. A message that varies by channel reads as noise;
a message that repeats reads as a product.

## The hook, in three lengths

**6 words** — Apps you describe instead of install.

**20 words** — You say "track my water intake". It builds a real full-stack app
on your phone. No code, no cloud.

**50 words** — Most apps are screens somebody chose in advance. Anything inverts
that: describe an outcome and it designs, validates and runs a real application
for it, natively, on your device. What it builds is data the runtime executes —
not code you now maintain. Apache-2.0, no account, no server.

---

## GitHub topics (already applied)

```
ai · ai-agents · android · app-generator · cross-platform · dart · dynamic-ui
flutter · generative-ai · generative-ui · groq · llm · llm-apps · local-first
mobile-app · natural-language-interface · no-code · offline-first
on-device-ai · privacy-first
```

Twenty is GitHub's maximum and all twenty are used. `flutter`, `generative-ai`,
`llm` and `local-first` are the high-traffic ones; `generative-ui` and
`on-device-ai` are the precise ones that put you in front of the right people.

## Hashtags by platform

Platforms differ more than people expect. Do not paste the same block everywhere.

**X / Twitter** — two or three, inline, never a wall.

```
#Flutter #GenerativeUI #LocalFirst
```

Rotate the third: `#AndroidDev` · `#OpenSource` · `#OnDeviceAI` · `#BuildInPublic`

**LinkedIn** — three to five, on their own line after the post.

```
#OpenSource #Flutter #GenerativeAI #MobileDevelopment #PrivacyByDesign
```

**Mastodon / Bluesky** — hashtags are the whole discovery mechanism there. Be
generous, and put them on the last line.

```
#Flutter #Dart #OpenSource #GenerativeAI #LocalFirst #Android #FOSS
```

**Reddit / Hacker News** — zero hashtags. They read as spam and will cost you
the post.

---

## Launch posts

### X / Twitter

```
Most apps are screens somebody picked in advance.

Anything inverts it: you describe an outcome, and it builds, validates and runs
a real full-stack app for it — on your phone, no account, no server.

What it generates is data the runtime executes, not code you now maintain.

Apache-2.0
SITE_URL

#Flutter #GenerativeUI #LocalFirst
```

Follow it with a reply carrying the demo GIF (`assets/screenshots/demo.gif`).
A media reply consistently outperforms media in the parent post.

### LinkedIn

```
I spent the last year on a question that would not leave me alone: why is most
software never written?

Not because it is hard. Because it is not worth it. A tool that helps exactly
one person for six weeks cannot justify a repo, a maintainer and a release
cycle. So it never exists, and that person does the thing by hand forever.

Anything is my attempt at moving that cost to roughly zero. You describe an
outcome — "track my water intake", "find nearby coffee shops" — and it designs,
validates and runs a real application for it. Natively. On your device. No
account, no server, no sync.

The part I am most proud of is not the AI. It is that what gets generated is
data rather than code. That single decision is what lets a generated app be
validated before it runs, revised without a merge, protected with encryption,
and deleted completely, leaving nothing behind. It cannot execute arbitrary
code, because there is no code to execute.

102 architectural invariants run on every commit, each one proven by
deliberately breaking it and watching the check fail.

Apache-2.0. Currently in closed testing on Google Play.

SITE_URL

#OpenSource #Flutter #GenerativeAI #MobileDevelopment #PrivacyByDesign
```

### Hacker News — Show HN

Title (80 characters, no hashtags, no emoji, no exclamation mark):

```
Show HN: Anything – describe an app and it builds and runs it on your phone
```

First comment, posted immediately after submitting:

```
I built this because most useful software never gets written — a tool that
helps one person for six weeks cannot justify a repo and a release cycle.

The design decision everything else follows from: what the model produces is a
validated data package, not source code. The runtime executes the package
directly. So a generated app can be checked exhaustively before it ever runs,
revised without a merge, encrypted at rest, and removed completely. It also
cannot execute arbitrary code, because there is no code to execute.

It runs on-device. No account, no server, no telemetry. You bring your own model
key (Groq today; the provider interface exists and has never had a second
implementation, which is genuinely good first-issue territory).

Honest about the gaps: accessibility is minimal, there is no localisation, and
one test in the suite hangs deterministically and I have not fixed it yet. The
roadmap says so too.

Happy to answer anything about the architecture.
```

HN rewards specificity and punishes marketing language. The paragraph admitting
the gaps is not modesty — it is the most persuasive one in the post.

### Reddit

| Subreddit | Lead with |
|---|---|
| r/FlutterDev | The architecture, not the product. This audience wants to know how the renderer walks a behaviour graph |
| r/androiddev | On-device generation, and the API 37 target |
| r/opensource | Apache-2.0, DCO instead of a CLA, and the invariant suite |
| r/selfhosted | "No server exists, so there is nothing to host" |

Read each subreddit's self-promotion rule first. Several require comment history
before you post your own project.

---

## Sequence

Launch is a day, not a moment.

1. **Repo public**, social preview uploaded, topics live.
2. **Show HN**, early US morning, Tuesday to Thursday. Highest ceiling and
   shortest half-life, so it goes first.
3. **r/FlutterDev**, same day, two or three hours later.
4. **X and LinkedIn**, same day, once there is a comment thread to point at.
5. **r/androiddev and r/opensource**, the following week. Never the same day —
   cross-posting one project across subreddits within hours is the fastest way
   to get filtered.

Answer every comment for the first 48 hours. Response rate matters more than
post copy: a thread where the author is present ranks and spreads.

---

## Before you press anything

- [ ] Repo public, with the history secret-scanned again first
- [ ] Social preview uploaded — GitHub **Settings → General → Social preview**,
      using `assets/branding/social-card.png` (1280×640). There is no API for
      this; it has to be done by hand, and without it every share falls back to
      a generic grey card
- [ ] `SITE_URL` resolves, and the privacy policy on it resolves — the Play
      listing points at that URL
- [ ] The demo GIF plays on GitHub
- [ ] Discussions enabled with a welcome post already there, so the first
      visitor does not land in an empty room
- [ ] Two or three issues labelled `good first issue` — accessibility,
      localisation, and the second `ModelProvider` are the obvious three
- [ ] CI green. A red X on the front page costs more credibility than any post
      copy can buy back. **It is currently red on formatting** — `dart format .`
      fixes it
