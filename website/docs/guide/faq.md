# FAQ

The full FAQ lives in the repository: [docs/FAQ.md](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/docs/FAQ.md). The most
common questions:

## Is it a chatbot?

No. The output is a running application with its own interface, behaviour and
state — not a message.

## Does it generate code I have to maintain?

No, and that is the point. It generates an **Experience**: a validated,
versioned package the runtime already knows how to execute. There is no source
file that becomes yours to keep working.

## Do I need an account?

No. There is no server and no sync. You do currently need an AI provider key,
which needs network access.

## Is it production ready?

No. The architecture is mature and heavily certified; the product is not
shipped. See the [roadmap](/guide/roadmap).

## Why do I see "ProviderRequired"?

No AI provider key is configured. Settings then AI Provider. This is a
deliberate honest failure rather than a crash or a fabricated answer.

## Can I share an Experience?

Yes, as of IS-P02. **My Apps, long-press, Export** writes a `.anything` file;
**Import** reads one back. A tampered file is refused.

## Where is my data?

On your device. SQLite for Experiences and knowledge, the platform keystore for
API keys. Nothing is uploaded.

## Can an Experience do something malicious?

It cannot execute arbitrary code — an Experience is *data*, a behaviour graph
the interpreter walks. Capabilities are enforced, and declaring one does not
grant it. See [SECURITY.md](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/SECURITY.md) for what is and is not protected.

## Do I own what I create?

Yes. Apache-2.0 covers the software, not the Experiences you generate with it.

## Can I use it commercially?

Yes. Apache-2.0 permits commercial use, modification and distribution, with
attribution and notice of changes.

## Is there a CLA?

No. DCO — sign off your commits with `git commit -s`. You keep ownership.
