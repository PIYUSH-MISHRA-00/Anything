# Using AI Providers in Anything

Anything has no account and no server. It uses **your** AI provider key,
stored in your phone's keystore. Nothing is uploaded except the text you ask a
model to work on, which goes to the provider you chose.

## Getting started

1. **Settings → AI Providers**
2. Tap **Groq** — the one tested against a live account
3. Get a free key at [console.groq.com/keys](https://console.groq.com/keys)
4. Paste it, tap **Test connection**, then **Save**

## Reading the list

| Badge | Meaning |
|---|---|
| **Tested** | Works, and has been checked against a real account |
| **Experimental** | Should work — same protocol — but not verified by the maintainers |
| **Coming soon** | Not built yet. Tap it and it tells you why |

Search by name, or filter by **Commercial / Open-weight / Local / Custom**.
Providers you have configured appear at the top under **Your providers**.

## What each provider needs

Every configuration screen opens with **WHAT THIS NEEDS**, before you paste
anything: whether a key is required, whether an address is required, which
model will be used, and **where your prompts go**.

## Your API key

- Masked by default; the **eye** reveals it so you can check a paste
- **Copy** puts it on the clipboard
- Reopening shows the stored key, so you can edit rather than retype
- **Remove** deletes the configuration *and* the key from your phone

## Choosing a model

**Refresh list** asks your provider what it hosts; tap a result to use it. You
can also type an ID directly — useful when a provider does not publish a list.

If a model is retired, Anything says so plainly and your key is untouched.

## Local models

Ollama, LM Studio, LocalAI, llama.cpp and vLLM run on your own computer, and
your prompts never leave your network.

**Enter your computer's address on your network — not `localhost`.** On a
phone, `localhost` means the phone. It looks like
`http://192.168.1.10:11434/v1`. Your phone and computer must be on the same
network.

No API key is needed. There is no default model — tap **Refresh list**.

## When something goes wrong

Anything never shows a raw error code. Each message says what happened and
what to do.

| Message | What it means |
|---|---|
| No API key was entered | The field is empty |
| That key was rejected | Wrong, revoked, or incompletely pasted |
| That key is valid but is not allowed | The key works; your account lacks access to that model |
| That model has been retired | **Your key is fine.** Pick a current model |
| … does not have a model with that name | Check the ID, or refresh |
| Nothing was found at that address | Check the endpoint URL |
| … is rate limiting this key | Wait and try again |
| … is having trouble at their end | Their outage, not your key |
| Could not reach … | You are offline, or the address is unreachable |
| … did not respond in time | Slow network or slow provider |
| That address answered, but not like an OpenAI-compatible API | Often a WiFi login page |

The screen also shows **when your key last worked** and **why it last failed**.

## Frequently asked

**Do I need a key?** Yes, to create anything. Anything runs without one, but
cannot create.

**Is my key uploaded?** No. It is in your phone's keystore and is sent only to
the provider you configured.

**Can I use more than one?** You can configure several; one is active at a
time, marked **Active**.

**Does removing a provider delete my apps?** No. Experiences already created
are unaffected. You cannot create new ones until a provider is configured.

**Which is cheapest?** Groq has a free tier. Local providers cost nothing
beyond your own hardware.
